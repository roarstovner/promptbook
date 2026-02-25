# pb_qmd() snapshot

    Code
      cat(pb_qmd(pb, "html"))
    Output
      ---
      title: "Media Framing Codebook"
      subtitle: "Version 1.0.0"
      author: "Jane Researcher"
      format:
        html:
          embed-resources: true
      ---
      
      Coding instrument for newspaper coverage of climate policy. Adapted from Semetko & Valkenburg (2000) framing typology.
      ## Basic codes
      
      Straightforward codes suitable for fast models
      
      ### Primary topic (`topic`)
      
      The dominant topic of the article. Choose the single best fit based on which topic receives the most coverage.
      
      | Value | Label | Description |
      |---|---|---|
      | economy | Economic impacts | Focus on costs, jobs, GDP, trade effects of climate policy |
      | health | Public health | Focus on health outcomes, disease, air quality |
      | environment | Environmental impacts | Focus on ecosystems, biodiversity, emissions, pollution |
      | politics | Political process | Focus on legislation, elections, party positions, lobbying |
      | technology | Technology and innovation | Focus on renewable energy, carbon capture, tech solutions |
      | other | Other | Does not fit any of the above categories |
      
      ### Overall policy sentiment (`sentiment`)
      
      The overall evaluative tone of the article toward the climate policy discussed. Use the full scale; reserve 3 for articles that are genuinely balanced with no detectable lean.
      
      **Type:** numeric (integer), range: 1–5
      
      | Value | Label |
      |---|---|
      | 1 | Very negative |
      | 2 | Somewhat negative |
      | 3 | Neutral / balanced |
      | 4 | Somewhat positive |
      | 5 | Very positive |
      
      ### All topics mentioned (`topics_all`)
      
      All topics that receive substantial coverage in the article. Select all that apply; most articles will have 1-3 topics.
      
      *Multiple values allowed.*
      
      | Value | Label | Description |
      |---|---|---|
      | economy | Economic impacts |  |
      | health | Public health |  |
      | environment | Environmental impacts |  |
      | politics | Political process |  |
      | technology | Technology and innovation |  |
      
      ### Contains quantitative data (`has_data`)
      
      Whether the article cites any specific numbers, statistics, or quantitative evidence (e.g., percentages, dollar amounts, counts).
      
      **Type:** boolean
      
      ## Framing analysis
      
      Complex interpretive codes requiring stronger reasoning
      
      ### Dominant frame (`frame`)
      
      The primary interpretive frame used to present the issue. Based on Semetko & Valkenburg (2000) generic news frames.
      
      | Value | Label | Description |
      |---|---|---|
      | conflict | Conflict | Emphasizes disagreement between parties, groups, or individuals |
      | consequence | Economic consequence | Emphasizes economic costs, benefits, or financial implications |
      | human_interest | Human interest | Emphasizes personal stories, emotional angles, or individual impact |
      | morality | Morality | Emphasizes moral or ethical considerations, right vs. wrong |
      | responsibility | Responsibility attribution | Emphasizes who is responsible for causing or solving the problem |
      
      ### Source diversity (`source_diversity`)
      
      How many distinct types of sources are quoted or cited (e.g., politicians, scientists, citizens, industry). Count source types, not individual sources.
      
      **Type:** numeric (integer), range: 0–10
      
      ### Most representative quote (`key_quote`)
      
      The single direct quote that best represents the article's main message. Copy verbatim from the article. Return an empty string if no direct quotes are present.
      
      **Type:** text
      
      ### Named actors (`actors`)
      
      All people or organizations that are quoted or whose positions are described in the article.
      
      *Multiple values allowed.*
      
      | Property | Type | Description |
      |---|---|---|
      | actor_name | text | Full name as mentioned in the article |
      | actor_type | categorical | Type of actor |
      | stance | categorical | The actor's stated or implied stance on the policy |
      
      ## System Prompt
      
      ```
      You are an expert content analyst trained in media framing analysis.
      You will be given a newspaper article and must code it according to
      the codebook variables defined below.
      
      Guidelines:
      - Read the full article before coding any variable.
      - Be conservative: if unsure between two categories, choose the
        more neutral or general option.
      - For the sentiment scale, use the full range; reserve 3 for
        articles that are genuinely balanced.
      ```

