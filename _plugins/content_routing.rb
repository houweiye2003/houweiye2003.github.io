# frozen_string_literal: true

# Student-facing pages need only a title and content. Language, URLs, layouts,
# and translation pairs are derived from their location, never from front matter.
module ContentRouting
  class Generator < Jekyll::Generator
    priority :highest

    def generate(site)
      languages = site.config.fetch("languages")
      default_language = site.config.fetch("defaultContentLanguage")
      unless languages.key?(default_language)
        raise Jekyll::Errors::FatalException, "defaultContentLanguage must be listed in languages"
      end

      # Each English publication is maintained once in publications/*.md.
      # Generate a page for each site's language so navigation stays localized.
      publications = site.pages.select do |page|
        File.dirname(page.relative_path) == "publications" && content_page?(page)
      end
      site.pages -= publications

      site.pages.each do |page|
        route = content_route(page, languages.keys)
        next unless route

        language, key = route
        publication = key.start_with?("publications/")
        page.data.merge!(
          "lang" => language,
          "content_key" => key,
          "content_type" => publication ? "publication" : "page",
          "layout" => publication ? "publication" : "page",
          "permalink" => "/#{language}/#{key}/"
        )
        # Plugins may have read the original URL before this generator ran.
        page.instance_variable_set(:@url, nil)
      end

      languages.each_key do |language|
        publications.each do |publication|
          page = Jekyll::PageWithoutAFile.new(site, site.source, "#{language}/publications", publication.name)
          page.content = publication.content.dup
          page.data.merge!(publication.data)
          key = publication.relative_path.sub(/\.[^.]+\z/, "")
          page.data.merge!(
            "lang" => language,
            "content_key" => key,
            "content_type" => "publication",
            "layout" => "publication",
            "permalink" => "/#{language}/#{key}/"
          )
          site.pages << page
        end
        add_page(site, language, "", "home", "home", languages[language].dig("params", "homeInfoParams", "Title"))
        add_page(site, language, "publications", "publications", "publications", site.data.fetch("i18n").fetch(language).fetch("publications"))
      end

      duplicates = site.pages.group_by(&:url).select { |_, pages| pages.size > 1 }
      return if duplicates.empty?

      raise Jekyll::Errors::FatalException, "Duplicate page URLs: #{duplicates.keys.join(', ')}"
    end

    private

    def content_page?(page)
      %w(.md .markdown .html).include?(page.ext.downcase)
    end

    def content_route(page, languages)
      return unless content_page?(page)

      parts = page.relative_path.sub(/\.[^.]+\z/, "").split("/")
      if languages.include?(parts.last) && parts.size > 1
        language = parts.pop
      elsif parts.size > 2 && languages.include?(parts[1])
        language = parts.delete_at(1)
        parts.pop if parts.last == "index"
      else
        return
      end
      [language, parts.join("/")]
    end

    def add_page(site, language, section, key, layout, title)
      return if site.pages.any? { |page| page.data["lang"] == language && page.data["content_key"] == key }

      page = Jekyll::PageWithoutAFile.new(site, site.source, File.join(language, section), "index.html")
      page.content = ""
      page.data.merge!(
        "title" => title,
        "layout" => layout,
        "lang" => language,
        "content_key" => key,
        "permalink" => "/#{[language, section].reject(&:empty?).join('/')}/"
      )
      site.pages << page
    end
  end
end
