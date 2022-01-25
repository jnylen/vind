defmodule Main.Router do
  use Main, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug(:accepts, ["html", "json"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {Main.LayoutView, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", Main do
    pipe_through(:browser)

    live_dashboard("/dashboard", metrics: Main.Telemetry)

    get("/", PageController, :index)

    get("/airing", AiringController, :index)
    get("/airing/:id", AiringController, :show)

    get("/channel", ChannelController, :index)
    get("/channel/new", ChannelController, :new)
    post("/channel/new", ChannelController, :new)
    get("/channel/run_job", ChannelController, :run_job)
    get("/channel/:id", ChannelController, :show)
    get("/channel/run_job/:id/:job", ChannelController, :run_job)
    get("/channel/edit/:id", ChannelController, :edit)
    put("/channel/edit/:id", ChannelController, :edit)
    delete("/channel/:id", ChannelController, :delete)
    get("/job", JobController, :index)

    # Augmenter Rules
    get("/augmenter_rule", AugmenterRuleController, :index)
    get("/augmenter_rule/new", AugmenterRuleController, :new)
    post("/augmenter_rule/new", AugmenterRuleController, :new)
    get("/augmenter_rule/edit/:id", AugmenterRuleController, :edit)
    put("/augmenter_rule/edit/:id", AugmenterRuleController, :edit)
    get("/augmenter_rule/delete/:id", AugmenterRuleController, :delete)

    # Category (Translations)
    get("/category", CategoryController, :index)
    get("/category/new", CategoryController, :new)
    post("/category/new", CategoryController, :new)
    get("/category/edit/:id", CategoryController, :edit)
    put("/category/edit/:id", CategoryController, :edit)
    get("/category/delete/:id", CategoryController, :delete)

    # Country (Translations)
    get("/country", CountryController, :index)
    get("/country/new", CountryController, :new)
    post("/country/new", CountryController, :new)
    get("/country/edit/:id", CountryController, :edit)
    put("/country/edit/:id", CountryController, :edit)
    get("/country/delete/:id", CountryController, :delete)

    # Email Rules
    get("/email_rule", EmailRuleController, :index)
    get("/email_rule/new", EmailRuleController, :new)
    post("/email_rule/new", EmailRuleController, :new)
    get("/email_rule/edit/:id", EmailRuleController, :edit)
    put("/email_rule/edit/:id", EmailRuleController, :edit)
    get("/email_rule/delete/:id", EmailRuleController, :delete)

    # Files
    get("/file", FileController, :index)
    # get("/file/new", FileController, :new)
    # post("/file/new", FileController, :new)
    live("/file/new", Live.FileUploadLive, :index)
    get("/file/:id", FileController, :show)

    # Batches
    get("/batch", BatchController, :index)
    get("/batch/:id", BatchController, :show)

    # FTP Rules
    get("/ftp_rule", FtpRuleController, :index)
    get("/ftp_rule/new", FtpRuleController, :new)
    post("/ftp_rule/new", FtpRuleController, :new)
    get("/ftp_rule/edit/:id", FtpRuleController, :edit)
    put("/ftp_rule/edit/:id", FtpRuleController, :edit)
    get("/ftp_rule/delete/:id", FtpRuleController, :delete)

    # Leagues (Translations)
    get("/league", LeagueController, :index)
    get("/league/new", LeagueController, :new)
    post("/league/new", LeagueController, :new)
    get("/league/edit/:id", LeagueController, :edit)
    put("/league/edit/:id", LeagueController, :edit)
    get("/league/delete/:id", LeagueController, :delete)

    # Teams (Translations)
    get("/team", TeamController, :index)
    get("/team/new", TeamController, :new)
    post("/team/new", TeamController, :new)
    get("/team/edit/:id", TeamController, :edit)
    put("/team/edit/:id", TeamController, :edit)
    get("/team/delete/:id", TeamController, :delete)
  end
end
