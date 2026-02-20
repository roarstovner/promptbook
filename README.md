# Promptbook -- an R package for documented, reproducible, reusable data annotation with LLMs

> [!WARNING]
> Promptbook is under active development and the first alpha is not yet released. Below is my ambition for the project.

My idea with promptbook is that data annotation with LLMs in R need a package that's well suited for research workflows. The typical case is when a researcher has a dataset with text snippets that should be coded with a coding instrument. The text snippets might be abstracts for journal articles, newspaper headlines, curricula in different countries, etc. The coding instrument is how to assign several codes (categorical or numeric or other) to each text snippet. There may be many codes, both 5 and 20 will be common. Promptbook must help the researcher

- make a codebook with information enough to assign the codes for a human coder
- have a "promptbook" with the LLM prompt (together with tool usage answer format, etc.) for an LLM to assign the codes
- a way to apply the promptbook to a dataset using `ellmer::`, either batched, in parallell, local, or otherwise.

I use "promptbook" to refer to both the codebook and promptbook.
 
Requirements:

- the promptbook can generate a human readable codebook, maybe with codebookr or another backend
- the promptbook is stored in a standard format as one or more files
- the promptbook can very easily be applied to data with ellmer

Here's an example of what I have in mind. First define a promptbook in yaml:

```yaml
# Example promptbook: Media framing of climate policy
# This is a complete, realistic example of a promptbook YAML file.

schema_version: 1
title: "Media Framing Codebook"
version: "1.0.0"
description: >
  Coding instrument for newspaper coverage of climate policy.
  Adapted from Semetko & Valkenburg (2000) framing typology.
author: "Jane Researcher"

prompt:
  system: |
    You are an expert content analyst trained in media framing analysis.
    You will be given a newspaper article and must code it according to
    the codebook variables defined below.

    Guidelines:
    - Read the full article before coding any variable.
    - Be conservative: if unsure between two categories, choose the
      more neutral or general option.
    - For the sentiment scale, use the full range; reserve 3 for
      articles that are genuinely balanced.
  user: |
    Please code the following newspaper article:

    {text}

variables:
  # --- Basic codes (group: basic) ---
  - name: topic
    label: "Primary topic"
    description: >
      The dominant topic of the article. Choose the single best fit
      based on which topic receives the most coverage.
    type: categorical
    categories:
      - value: "economy"
        label: "Economic impacts"
        description: "Focus on costs, jobs, GDP, trade effects of climate policy"
      - value: "health"
        label: "Public health"
        description: "Focus on health outcomes, disease, air quality"
      - value: "environment"
        label: "Environmental impacts"
        description: "Focus on ecosystems, biodiversity, emissions, pollution"
      - value: "politics"
        label: "Political process"
        description: "Focus on legislation, elections, party positions, lobbying"
      - value: "technology"
        label: "Technology and innovation"
        description: "Focus on renewable energy, carbon capture, tech solutions"
      - value: "other"
        label: "Other"
        description: "Does not fit any of the above categories"
    group: basic

  - name: sentiment
    label: "Overall policy sentiment"
    description: >
      The overall evaluative tone of the article toward the climate
      policy discussed. Use the full scale; reserve 3 for articles
      that are genuinely balanced with no detectable lean.
    type: numeric
    min: 1
    max: 5
    labels:
      1: "Very negative"
      2: "Somewhat negative"
      3: "Neutral / balanced"
      4: "Somewhat positive"
      5: "Very positive"
    group: basic
```

Then, you can code your data with this promptbook:

```r
library(promptbook)

pb <- read_promptbook("media_framing.yaml")
articles <- read.csv("articles.csv")
results <- pb_annotate(articles, pb, text = article_text)

# results is a data frame with all original columns + coded variables
table(results$topic)
mean(results$sentiment)
```
