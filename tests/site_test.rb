# frozen_string_literal: true

# Integration checks: build real pages, then inspect the generated HTML and files.
require "jekyll"
require "nokogiri"
require "addressable/uri"
require "fileutils"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)

def check(condition, message)
  raise message unless condition
end

def build(source, destination, overrides = {})
  config = Jekyll.configuration({
    "source" => source,
    "destination" => destination,
    "config" => File.join(source, "_config.yml"),
    "quiet" => true,
  }.merge(overrides))
  Dir.chdir(source) do
    site = Jekyll::Site.new(config)
    site.process
    site
  end
end

def document(destination, route)
  filename = File.join(destination, route, "index.html")
  check(File.file?(filename), "Missing generated page: #{route}")
  Nokogiri::HTML(File.read(filename))
end

def check_translation(document, language, expected)
  switch = document.at_css(".language-switch a[hreflang='#{language}']")
  check(switch && switch["href"] == expected, "Wrong language switch: expected #{expected}")
  alternate = document.at_css("link[rel='alternate'][hreflang='#{language}']")
  check(alternate && alternate["href"].end_with?(expected), "Missing alternate URL: #{expected}")
end

def check_local_links(destination, site)
  baseurl = site.config.fetch("baseurl")
  host = Addressable::URI.parse(site.config.fetch("url")).host
  failures = []
  Dir.glob(File.join(destination, "**", "*.html")).each do |filename|
    relative = filename.delete_prefix(destination + "/")
    doc = Nokogiri::HTML(File.read(filename))
    doc.css("a[href], link[href], img[src], script[src]").each do |node|
      href = node["href"] || node["src"]
      next if href.start_with?("#", "mailto:", "tel:", "data:")

      uri = Addressable::URI.parse(href)
      next if uri.host && uri.host != host

      path = Addressable::URI.unencode(uri.path.to_s)
      if path.start_with?("/")
        unless baseurl.empty? || path.start_with?(baseurl + "/")
          failures << "#{relative}: missing baseurl in #{href}"
          next
        end
        path = path.delete_prefix(baseurl)
        target = File.join(destination, path.delete_prefix("/"))
      else
        target = File.expand_path(path, File.dirname(filename))
      end
      target = File.join(target, "index.html") if File.directory?(target)
      failures << "#{relative}: broken link #{href}" unless File.file?(target)
    end
  end
  check(failures.empty?, failures.join("\n"))
end

Dir.mktmpdir("homepage-check-") do |temporary|
  source = File.join(temporary, "source")
  FileUtils.mkdir_p(source)
  Dir.children(ROOT).each do |entry|
    next if entry.start_with?(".") || %w(vendor _site tests).include?(entry)

    FileUtils.cp_r(File.join(ROOT, entry), source)
  end

  destination = File.join(temporary, "site")
  site = build(source, destination)
  %w(en zh).each do |language|
    document(destination, language)
    document(destination, "#{language}/about")
    document(destination, "#{language}/research")
    listing = document(destination, "#{language}/publications")
    check(listing.css(".pub-entry").size == 2, "Publication listing should include both papers")
    home = document(destination, language)
    check(home.css(".pub-entry").size == 1, "Homepage should include only selected papers")
    paper = document(destination, "#{language}/publications/1")
    other = language == "en" ? "zh" : "en"
    check_translation(paper, site.config["languages"][other]["locale"], "/#{other}/publications/1/")
    check(paper.at_css(".publication-links a[href*='/publications/pdf/']"), "Missing paper PDF link")
    check(paper.at_css(".breadcrumbs a[href='/#{language}/publications/']"), "Wrong publication breadcrumb")
    check(home.at_css("img.portrait[src='/images/portrait.webp']"), "Portrait must use the config path")
  end
  english_paper = document(destination, "en/publications/1")
  chinese_paper = document(destination, "zh/publications/1")
  check(english_paper.at_css("h1").text == chinese_paper.at_css("h1").text, "Publication titles must be shared")
  check(english_paper.at_css(".post-content").inner_html == chinese_paper.at_css(".post-content").inner_html, "Publication text must be shared")
  check(english_paper.at_css("html")["lang"] == "en-US" && chinese_paper.at_css("html")["lang"] == "zh-CN", "Publication navigation must keep the site's language")
  check(english_paper.at_css(".publication-links").text.include?("Publication page"), "English paper buttons must be localized")
  check(chinese_paper.at_css(".publication-links").text.include?("论文主页"), "Chinese paper buttons must be localized")
  check(!File.exist?(File.join(destination, "publications/1.html")), "Shared sources must only produce localized publication pages")
  check_translation(document(destination, "en/about"), "zh-CN", "/zh/about/")
  check_local_links(destination, site)
  check(!File.exist?(File.join(destination, "hugo.yaml")), "Reference configuration must not be published")
  check(Dir.glob(File.join(destination, "**", "posts")).empty?, "Posts must be removed")
  check(Dir.glob(File.join(destination, "**", "pubs")).empty?, "Short publication routes must be removed")
  check(site.data.keys == ["i18n"], "_data should only contain i18n")
  check(site.data["i18n"]["en"].keys.sort == site.data["i18n"]["zh"].keys.sort, "Translation keys must match")

  # A student adds a new section and a new paper without any routing metadata.
  { "abc/en.md" => "ABC", "abc/zh.md" => "新栏目",
    "abc/en/nested.md" => "Nested", "abc/zh/nested.md" => "子页面",
    "abc/en/only-english.md" => "English only" }.each do |path, title|
    target = File.join(source, path)
    FileUtils.mkdir_p(File.dirname(target))
    File.write(target, "---\ntitle: #{title}\n---\n\nPage body.\n")
  end
  added_paper = File.join(source, "publications", "first-paper.md")
  File.write(added_paper, <<~PAPER)
    ---
    title: Added paper
    selected: true
    order: 3
    paper: added-paper.pdf
    summary: Added once without language, identifiers, layout, or permalink.
    ---

    Shared English publication body with **Markdown**.
  PAPER
  File.write(File.join(source, "publications/pdf/added-paper.pdf"), "%PDF-1.4\n")

  languages = Marshal.load(Marshal.dump(site.config.fetch("languages")))
  languages.each_value do |settings|
    settings.fetch("menu").fetch("main") << { "name" => "ABC", "pageRef" => "/abc/", "weight" => 70 }
  end
  site = build(source, destination, "baseurl" => "/preview", "defaultContentLanguage" => "en", "languages" => languages)
  check_translation(document(destination, "en/abc"), "zh-CN", "/preview/zh/abc/")
  check(document(destination, "en/abc").at_css("#menu a[href='/preview/en/abc/'][aria-current='page']"), "New page menu must use config and show the active section")
  check_translation(document(destination, "en/abc/nested"), "zh-CN", "/preview/zh/abc/nested/")
  check_translation(document(destination, "zh/publications/first-paper"), "en-US", "/preview/en/publications/first-paper/")
  check(document(destination, "en/publications").css(".pub-entry").size == 3, "New paper must appear automatically")
  check(document(destination, "en").css(".pub-entry").size == 2, "New selected paper must appear on the homepage")
  %w(en zh).each do |language|
    new_paper = document(destination, "#{language}/publications/first-paper")
    check(new_paper.at_css(".post-content strong").text == "Markdown", "Shared publication body must render Markdown for both languages")
    check(new_paper.at_css(".publication-links a[href='/preview/publications/pdf/added-paper.pdf']"), "Both languages must link to the same PDF")
    check(document(destination, "#{language}").css(".pub-entry").size == 2, "Both homepages must use the shared selection")
    check(document(destination, "#{language}/publications").css(".pub-entry").size == 3, "Both listings must include a paper added once")
  end
  switch = document(destination, "en/abc/only-english").at_css(".language-switch a")
  check(switch["href"] == "/preview/zh/", "Missing translation should fall back to the other homepage")
  root = Nokogiri::HTML(File.read(File.join(destination, "index.html")))
  check(root.at_css("meta[http-equiv='refresh']")["content"] == "0; url=/preview/en/", "Root redirect must follow config")
  check_local_links(destination, site)

  params = site.config.fetch("params").merge(
    "ShowOnlySelectedPubs" => false,
    "ShowBreadCrumbs" => false,
    "ShowCodeCopyButtons" => false
  )
  File.write(added_paper, File.read(added_paper).sub("Added paper", "Updated shared paper"))
  build(source, destination, "params" => params)
  home = document(destination, "en")
  check(home.css(".pub-entry").size == 3, "Disabling selection should show all papers")
  check(home.at_css("body")["data-copy-enabled"] == "false", "Copy setting must reach the page")
  check(document(destination, "en/about").css(".breadcrumbs").empty?, "Breadcrumb setting must be respected")
  %w(en zh).each do |language|
    check(document(destination, "#{language}/publications/first-paper").at_css("h1").text == "Updated shared paper", "One edit must update both publication pages")
    check(document(destination, language).css(".pub-entry h3").map(&:text).include?("Updated shared paper"), "One edit must update both homepages")
    check(document(destination, "#{language}/publications").css(".pub-entry h3").map(&:text).include?("Updated shared paper"), "One edit must update both listings")
  end

  # Conflicting filenames must fail instead of silently overwriting a page.
  FileUtils.mkdir_p(File.join(source, "abc/en"))
  File.write(File.join(source, "abc/en/index.md"), "---\ntitle: Duplicate\n---\n")
  begin
    build(source, destination)
    raise "Duplicate routes were silently accepted"
  rescue Jekyll::Errors::FatalException => error
    check(error.message.include?("Duplicate page URLs"), "Unexpected build error: #{error.message}")
  end
end

puts "Passed: shared publications, generated routes, translations, PDFs, listings, new sections, config settings, and local links."
