# print.promptbook produces expected output

    Code
      print(pb)
    Message
      # A promptbook: Media Framing Codebook
      # Version: 1.0.0
      # Variables: 8 (2 groups)
      # Groups: basic (haiku), framing (sonnet)

# print.pb_variable produces expected output

    Code
      print(pb$variables[[1]])
    Message
      <categorical> topic (group: basic)
    Code
      print(pb$variables[[2]])
    Message
      <numeric> sentiment (group: basic)
    Code
      print(pb$variables[[3]])
    Message
      <categorical [multiple]> topics_all (group: basic)
    Code
      print(pb$variables[[4]])
    Message
      <boolean> has_data (group: basic)
    Code
      print(pb$variables[[7]])
    Message
      <text> key_quote (group: framing)
    Code
      print(pb$variables[[8]])
    Message
      <object [multiple]> actors (group: framing)

