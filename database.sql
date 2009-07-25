-- Use InnoDB for transaction support.
SET storage_engine=InnoDB;

DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS milestones;
DROP TABLE IF EXISTS teams;
DROP TABLE IF EXISTS milestone_bookmark;
DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS kills_by_ghosts;
DROP TABLE IF EXISTS kills_of_ghosts;
DROP TABLE IF EXISTS kills_of_uniques;
DROP TABLE IF EXISTS kunique_times;
DROP TABLE IF EXISTS rune_finds;
DROP TABLE IF EXISTS streaks;
DROP TABLE IF EXISTS player_won_gods;
DROP TABLE IF EXISTS player_points;
DROP TABLE IF EXISTS clan_points;

DROP VIEW IF EXISTS fastest_realtime;
DROP VIEW IF EXISTS fastest_turncount;
DROP VIEW IF EXISTS combo_highscores;
DROP VIEW IF EXISTS combo_win_highscores;
DROP VIEW IF EXISTS species_highscores;
DROP VIEW IF EXISTS class_highscores;
DROP VIEW IF EXISTS game_species_highscores;
DROP VIEW IF EXISTS game_class_highscores;
DROP VIEW IF EXISTS game_combo_highscores;
DROP VIEW IF EXISTS clan_combo_highscores;
DROP VIEW IF EXISTS clan_total_scores;
DROP VIEW IF EXISTS clan_unique_kills;
DROP VIEW IF EXISTS game_combo_win_highscores;
DROP VIEW IF EXISTS combo_hs_scoreboard;
DROP VIEW IF EXISTS combo_hs_clan_scoreboard;
DROP VIEW IF EXISTS streak_scoreboard;

CREATE TABLE IF NOT EXISTS players (
  name VARCHAR(20) PRIMARY KEY,
  team_captain VARCHAR(20),
  score_base BIGINT,
  -- This is the computed score! We will overwrite it each time we
  -- recalculate it, and it may be null at any point.
  score_full BIGINT DEFAULT 0,
  team_score_base BIGINT,
  -- This is also computed and will be overwritten each time.
  team_score_full BIGINT DEFAULT 0,
  FOREIGN KEY (team_captain) REFERENCES players (name)
  ON DELETE SET NULL
  );
  
CREATE INDEX pscore ON players (score_full);

CREATE TABLE teams (
  owner VARCHAR(20) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  -- Clan total score, will be recomputed at intervals.
  total_score BIGINT DEFAULT 0 NOT NULL,
  PRIMARY KEY (owner),
  FOREIGN KEY (owner) REFERENCES players (name)
  ON DELETE CASCADE
  );

-- For mappings of logfile fields to columns, see loaddb.py
CREATE TABLE games (
  id BIGINT AUTO_INCREMENT,
  
  -- Source logfile
  source_file VARCHAR(150),
  -- Offset in the source file.
  source_file_offset BIGINT,

  player VARCHAR(20),
  start_time DATETIME,
  score BIGINT,
  race CHAR(20),
  -- Two letter race abbreviation so we can group by it without pain.
  raceabbr CHAR(2) NOT NULL,
  class CHAR(20),
  version CHAR(10),
  lv CHAR(8),
  uid INT,
  charabbrev CHAR(4),
  xl INT,
  skill CHAR(16),
  sk_lev INT,
  title VARCHAR(255),
  place CHAR(16),
  branch CHAR(16),
  lvl INT,
  ltyp CHAR(16),
  hp INT,
  maxhp INT,
  maxmaxhp INT,
  strength INT,
  intelligence INT,
  dexterity INT,
  god VARCHAR(20),
  duration INT,
  turn BIGINT,
  runes INT DEFAULT 0,
  killertype CHAR(20),
  killer CHAR(50),
  kgroup CHAR(50),
  kaux VARCHAR(255),
  -- Kills may be null.
  kills INT,
  damage INT,
  piety INT,
  penitence INT,
  end_time DATETIME,
  terse_msg VARCHAR(255),
  verb_msg VARCHAR(255),
  nrune INT DEFAULT 0,

  CONSTRAINT PRIMARY KEY (id)
  );

CREATE INDEX games_source_offset ON games (source_file, source_file_offset);

CREATE INDEX games_kgrp ON games (kgroup);
CREATE INDEX games_charabbrev_score ON games (charabbrev, score);
CREATE INDEX games_ktyp ON games (killertype);
CREATE INDEX games_p_ktyp ON games (player, killertype);

-- Index to find games with fewest kills.
CREATE INDEX games_kills ON games (killertype, kills);

-- Index to help us find fastest wins (time) quick.
CREATE INDEX games_win_dur ON games (killertype, duration);

-- Index to help us find fastest wins (turncount) quick.
CREATE INDEX games_win_turn ON games (killertype, turn);

CREATE TABLE milestones (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  -- Source milestone file
  source_file VARCHAR(150),

  -- The actual game that this milestone is linked with.
  game_id BIGINT,

  version VARCHAR(10),
  cv VARCHAR(10),
  player VARCHAR(20),
  race VARCHAR(20),
  raceabbr CHAR(2) NOT NULL,
  class VARCHAR(20),
  charabbrev CHAR(4),
  xl INT,
  skill VARCHAR(16),
  sk_lev INT,
  title VARCHAR(50),
  place VARCHAR(16),

  branch VARCHAR(16),
  lvl INT,
  ltyp VARCHAR(16),
  hp INT,
  maxhp INT,
  maxmaxhp INT,
  strength INT,
  intelligence INT,
  dexterity INT,
  god VARCHAR(50),
  duration BIGINT,
  turn BIGINT,
  runes INT,
  nrune INT,

  -- Game start time.
  start_time DATETIME,

  -- Milestone time.
  milestone_time DATETIME,

  -- Known milestones: abyss.enter, abyss.exit, rune, orb, ghost, uniq,
  -- uniq.ban, br.enter, br.end.
  verb VARCHAR(20),
  noun VARCHAR(100),

  -- The actual milestone message.
  milestone VARCHAR(255),

  FOREIGN KEY (game_id) REFERENCES games (id)
  ON DELETE SET NULL
);

-- To find milestones belonging to a particular game.
CREATE INDEX milestone_lookup_by_time ON milestones (player, start_time, verb);

-- A table to keep track of the last milestone we've processed. This
-- will have only one row for one filename.
CREATE TABLE milestone_bookmark (
  source_file VARCHAR(150) PRIMARY KEY,
  source_file_offset BIGINT
  );

CREATE TABLE kills_by_ghosts (
  killed_player CHAR(20) NOT NULL,
  killed_start_time DATETIME NOT NULL,
  killer CHAR(20) NOT NULL
  );

CREATE TABLE kills_of_ghosts (
  player CHAR(20),
  start_time DATETIME,
  ghost CHAR(20)
  );

CREATE TABLE kills_of_uniques (
  player CHAR(20) NOT NULL,
  kill_time DATETIME NOT NULL,
  monster CHAR(20),
  FOREIGN KEY (player) REFERENCES players (name)
  );

CREATE INDEX kill_uniq_pmons ON kills_of_uniques (player, monster);

-- Keep track of who's killed how many uniques, and when they achieved this.
CREATE TABLE kunique_times (
  player VARCHAR(20) PRIMARY KEY,
  -- Number of distinct uniques slain.
  nuniques INT DEFAULT 0 NOT NULL,
  -- When this number was reached.
  kill_time DATETIME NOT NULL,
  FOREIGN KEY (player) REFERENCES players (name) ON DELETE CASCADE
  );

CREATE TABLE rune_finds (
  player CHAR(20),
  start_time DATETIME,
  rune CHAR(20),
  FOREIGN KEY (player) REFERENCES players (name) ON DELETE CASCADE
  );

-- Generated table to keep track of streaks for each player.
CREATE TABLE streaks (
  player CHAR(20) PRIMARY KEY,
  -- Because you just know Stabwound's going to win 128 in a row
  streak MEDIUMINT NOT NULL,
  streak_time DATETIME NOT NULL,
  FOREIGN KEY (player) REFERENCES players (name)
  );

CREATE TABLE player_won_gods (
  player VARCHAR(20),
  god VARCHAR(20),
  FOREIGN KEY (player) REFERENCES players (name) ON DELETE CASCADE
);

-- Audit table for point assignment. Tracks both permanent and
-- temporary points.

CREATE TABLE player_points (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  player CHAR(20) NOT NULL,
  temp BOOLEAN DEFAULT 0,
  points MEDIUMINT NOT NULL DEFAULT 0,
  team_points MEDIUMINT NOT NULL DEFAULT 0,
  point_source VARCHAR(150) NOT NULL,
  FOREIGN KEY (player) REFERENCES players (name)
  );

CREATE INDEX point_player_src ON player_points (player, point_source);

-- Clan point assignments.
CREATE TABLE clan_points (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  captain CHAR(20) NOT NULL,
  points MEDIUMINT NOT NULL DEFAULT 0,
  point_source VARCHAR(150) NOT NULL,
  FOREIGN KEY (captain) REFERENCES players (name)
  );

-- Views for trophies

-- The three fastest realtime wins. Ties are broken by who got there first.
CREATE VIEW fastest_realtime AS
SELECT id, player, duration
  FROM games
 WHERE killertype = 'winning'
 ORDER BY duration, end_time
 LIMIT 3;

-- The three fastest wins (turncount)
CREATE VIEW fastest_turncount AS
SELECT id, player, turn
  FROM games
 WHERE killertype = 'winning'
ORDER BY turn, end_time
LIMIT 3;

CREATE VIEW most_pacific_wins AS
SELECT id, player, kills
  FROM games
 WHERE killertype = 'winning' AND kills IS NOT NULL
ORDER BY kills
 LIMIT 3;

-- All combo highscores.
CREATE VIEW combo_highscores AS
SELECT charabbrev, MAX(score) score
FROM games
GROUP BY charabbrev;

-- Winning combo highscores.
CREATE VIEW combo_win_highscores AS
SELECT charabbrev, MAX(score) score
FROM games
WHERE killertype = 'winning'
GROUP BY charabbrev;

CREATE VIEW game_combo_highscores AS
SELECT p.*
FROM games p,
     combo_highscores pmax
WHERE p.charabbrev = pmax.charabbrev
AND p.score = pmax.score;

CREATE VIEW clan_combo_highscores AS
SELECT p.team_captain, g.*
FROM game_combo_highscores g, players p
WHERE g.player = p.name
AND p.team_captain IS NOT NULL;

CREATE VIEW combo_hs_clan_scoreboard AS
SELECT team_captain, COUNT(*) AS combos
FROM clan_combo_highscores
GROUP BY team_captain
ORDER BY combos DESC
LIMIT 10;

CREATE VIEW clan_total_scores AS
SELECT team_captain, (SUM(score_full) + SUM(team_score_full)) score
FROM players
WHERE team_captain IS NOT NULL
GROUP BY team_captain
ORDER BY score DESC;

CREATE VIEW clan_unique_kills AS
SELECT p.team_captain AS team_captain, COUNT(DISTINCT monster) AS kills
FROM players p INNER JOIN kills_of_uniques k
                       ON p.name = k.player
WHERE p.team_captain IS NOT NULL
GROUP BY p.team_captain
ORDER BY kills DESC
LIMIT 10;

CREATE VIEW game_combo_win_highscores AS
SELECT p.*
FROM games p,
     combo_win_highscores pmax
WHERE p.charabbrev = pmax.charabbrev
AND p.score = pmax.score;

CREATE VIEW species_highscores AS
SELECT raceabbr, MAX(score) score
FROM games
GROUP BY raceabbr;

CREATE VIEW game_species_highscores AS
SELECT p.*
FROM games p,
     species_highscores pmax
WHERE p.raceabbr = pmax.raceabbr
AND p.score = pmax.score;

CREATE VIEW class_highscores AS
SELECT class, MAX(score) score
FROM games
GROUP BY class;

CREATE VIEW game_class_highscores AS
SELECT p.*
FROM games p,
     class_highscores pmax
WHERE p.class = pmax.class
AND p.score = pmax.score;

CREATE VIEW combo_hs_scoreboard AS
SELECT player, COUNT(*) AS nscores
FROM game_combo_highscores
GROUP BY player
ORDER BY nscores DESC
LIMIT 3;

CREATE VIEW streak_scoreboard AS
SELECT player, streak
FROM streaks
ORDER BY streak DESC, streak_time
LIMIT 3;