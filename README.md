要做的事情：
1. 删掉文件夹里的`cv.pdf`并在相同位置上传同名的文件`cv.pdf`
2. 按照下面的填写说明，修改`_config.yml`
3. 按照下面的填写说明，修改`about`、``research`里的md文件
4. 按照....(省略😂)，在`publications`文件夹里新建md文件（一篇文章一个哦）并在`pdf`子文件夹里上传对应文章的pdf文件，然后把pdf文件的名字填到对应文章的md文件里

# 网站填写说明
## 修改姓名、头像、首页介绍和链接

打开 `_config.yml`，按照带 **“(填写)”** 的中文注释填写。

- `title`：网站名称。
- `params`：中英文共用的姓名、网站描述、头像、简历按钮和社交链接。
- `languages.zh`：中文首页标题、自我介绍和中文菜单。
- `languages.en`：英文首页标题、自我介绍和英文菜单。

头像放在 `images/`，简历放在根目录的 `cv.pdf`。
`Content: |` 下的自我介绍可以换行，但每行前面的空格要保留。
 `_data/`中的 `i18n.yaml` 只存放网页界面（比如按钮）的中英文翻译，基本不需要修改。

## 修改关于和科研页面

编辑 `about/zh.md`、`about/en.md`、`research/zh.md` 或 `research/en.md`。
文件开头两条 `---` 之间是标题，下面是正文。中文和英文内容分别填写到zh.md和en.md。

## 添加论文

1. 在 `publications/` 中复制一篇现有论文的md文件，改名为 `SrTiO3.md` `270102-prl.md`等易于识别的名字。
2. 按文件内的“填写”标记修改标题、作者、期刊、简介和链接。不需要的可选链接留空。
3. 将 PDF 放入 `publications/pdf/`，在论文的md文件的 `paper:` 后填写文件名，例如 `paper: first-paper-on-SrTiO3-ferroelectric-switching.pdf`。

pdf文件名称推荐用减号（也就是短横线）来代替空格和标点，并保持全部小写。

`selected: true` 表示在首页中展示；`false` 表示仅在论文列表中展示。
`order:` 数字越小越靠前。

## 新建菜单栏目，例如 会议/Talks/Meetings

1. 新建 `meetings/` 文件夹。
2. 将 `about`文件夹里的`zh.md` 和 `en.md` 复制到该文件夹。
3. 修改两个md文件的标题和正文。
4. 在 `_config.yml` 对应语言的 `menu.main` 下照猫画虎添加相应栏目