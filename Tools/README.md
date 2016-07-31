# Tools

## Catalog.swift

* markdown 目录插入程序 Markdown catalog inset tool
* Use
    * 修改文件的 file 变量为 markdown 文件路径。
    * 终端输入
    * cd <文件夹路径>
    * swiftc Catalog.swift && ./Catalog && rm ./Catalog
* 示例
```
// 修改前 Test.md

<!--Catalog-->

# 标题1
    正文
# 标题2
    正文
## 标题2.1
    正文

// 修改后 Test.md

<!--Catalog-->
<!--Myron Catalog Start-->

* [ 标题1](#Myron_Catalog_0)
* [ 标题2](#Myron_Catalog_1)
    * [ 标题2.1](#Myron_Catalog_2)

<!--Myron Catalog End-->
<h5 id="Myron_Catalog_0"> </h5>
# 标题1
    正文
<h5 id="Myron_Catalog_1"> </h5>
# 标题2
    正文
<h5 id="Myron_Catalog_2"> </h5>
## 标题2.1
    正文
```
