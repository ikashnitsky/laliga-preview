# ..........................................................
# 2026-03-20 -- laliga predictions outcomes
# La Liga Preview pundits' odds                -----------
# Ilya Kashnitsky, ilya.kashnitsky@gmail.com
# ..........................................................

# This code analyzes the predictions made by pundits for La Liga matches in the season 2025-2026, up to matchday 28 with no predictions for matchdays 6 and 18. You can find the podcast episodes with these predictions here:
# https://youtube.com/playlist?list=PLZgJT1M3SJ9XVvZFlcJeCKUMzrMYCrCwc&si=RVs-ryd-bKHXuOBB
# I made screenshots of the predictions (you can fund them in "dat/screenshots") and with the help of Gemini and Claude compiled them into a clean table "dat/full-table-odds.csv".
# Additionally, "dat/laliga-played-matches.csv" containes a dump of all played matches in the season with the final scores, which was used in the data processing to decipher the team names where LLMs failed at the first run.
# Some of the early analysis performed by Claude in python and translated into R can be found here:
# https://www.perplexity.ai/search/here-i-have-a-table-with-perfo-J8InuNP2Q5yiMH9oPnjDbw

# Below is the R code with my final touches


library(tidyverse)
library(janitor)
devtools::source_gist("653e1040a07364ae82b1bb312501a184")
sysfonts::font_add_google("Atkinson Hyperlegible", family = "ah")
theme_set(theme_ik(base_family = "ah"))

# read in the data and clean the column names
df <- read_csv("dat/full-table-odds.csv") |>
  clean_names()

one <- df |>
  transmute(
    matchday,
    home_team,
    away_team,
    final_score,
    name = pundit_1_name,
    odds = pundit_1_odds,
    result = pundit_1_result
  )

two <- df |>
  transmute(
    matchday,
    home_team,
    away_team,
    final_score,
    name = pundit_2_name,
    odds = pundit_2_odds,
    result = pundit_2_result
  )

all_picks <- bind_rows(one, two) |>
  mutate(
    result = case_when(
      result == "✔" ~ "Win",
      result == "X" ~ "Loss",
      result == "🔄" ~ "Push",
      TRUE ~ "Unknown"
    )
  )


# simple summary
all_picks |>
  group_by(name) |>
  summarize(
    Win = sum(result == "Win"),
    Loss = sum(result == "Loss"),
    Push = sum(result == "Push"),
    # Sum only the odds where the result was a Win
    `Sum of Win Odds` = sum(odds[result == "Win"], na.rm = TRUE)
  ) |>
  mutate(
    `Total Bets` = (Win + Loss + Push),
    `Win Prop` = Win / (Win + Loss + Push)
  ) |>
  arrange(desc(`Win Prop`)) |>
  view()


# now let's see which teams are the winning for our experts
expanded <- bind_rows(
  all_picks |> mutate(team = home_team),
  all_picks |> mutate(team = away_team)
)

# calculate win rates
stats <- expanded |>
  group_by(name, team) |>
  summarise(Wins = sum(result == "Win"), Total = n(), .groups = "drop") |>
  mutate(
    WinRate = round(Wins / Total * 100, 1),
    Label = paste0(Wins, "/", Total, "\n", WinRate, "%"),
    # Dynamically adjust text color for contrast against magma background
    Text_Color = case_when(WinRate |> between(25, 75) ~ "black", TRUE ~ "white")
  )

# visualize the win rates by team
stats |>
  ggplot() +
  aes(x = name, y = reorder(team, WinRate, mean), fill = WinRate) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(
    aes(label = Label, color = Text_Color),
    size = 3,
    lineheight = 0.9,
    fontface = "bold"
  ) +
  scale_fill_viridis_c(
    option = "H",
    name = "Win\nRate %",
    limits = c(0, 100),
    direction = -1,
    guide = guide_colorbar(
      barwidth = 2,
      barheight = 30
    )
  ) +
  scale_color_identity() +
  scale_x_discrete(position = "top") +
  labs(
    title = "Pundit Win Rate by La Liga Team",
    subtitle = "Cells show wins / picks and win rate %",
    caption = "Data: YouTube show Comment.Preview // Analysis and graphic: Ilya Kashnitsky, @ikashnitsky.phd",
    x = NULL,
    y = NULL
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 24),
    plot.subtitle = element_text(size = 16, color = "#269292"),
    plot.caption = element_text(size = 8, color = "#269292"),
    axis.text.x = element_text(face = "bold", size = 16, color = "#074444"),
    axis.text.y = element_text(face = "bold", size = 12),
    panel.grid = element_blank(),
    legend.position = "right"
  )

# save the plot
ggsave(
  "out/by-team.png",
  width = 8,
  height = 8,
  dpi = 300
)
