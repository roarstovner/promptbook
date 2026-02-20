# Promptbook -- an R package for documented, reproducible, reusable data annotation with LLMs

My idea with promptbook is that data annotation with LLMs in R need a package that's well suited for research workflows. The typical case is when a researcher has a dataset with text snippets that should be coded with a coding instrument. The text snippets might be abstracts for journal articles, newspaper headlines, curricula in different countries, etc. The coding instrument is how to assign several codes (categorical or numeric or other) to each text snippet. There may be many codes, both 5 and 20 will be common. Promptbook must help the researcher

- make a codebook with information enough to assign the codes for a human coder
- have a "promptbook" with the LLM prompt (together with tool usage answer format, etc.) for an LLM to assign the codes
- a way to apply the promptbook to a dataset using `ellmer::`, either batched, in parallell, local, or otherwise.

I use "promptbook" to refer to both the codebook and promptbook.
 
Requirements:

- the promptbook can generate a human readable codebook, maybe with codebookr or another backend
- the promptbook is stored in a standard format as one or more files
- the promptbook can very easily be applied to data with ellmer
