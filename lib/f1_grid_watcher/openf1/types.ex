defmodule F1GridWatcher.OpenF1.Types do
  @moduledoc """
  Type specifications for OpenF1 API responses.

  All types are based on the official OpenF1 API documentation:
  https://openf1.org/?javascript#api-endpoints
  """

  @typedoc """
  Driver information from the API.
  """
@type driver :: %{
    optional(atom()) => term(),
    broadcast_name: String.t(),
    country_code: String.t(),
    driver_number: integer(),
    first_name: String.t(),
    full_name: String.t(),
    headshot_url: String.t(),
    last_name: String.t(),
    meeting_key: integer(),
    name_acronym: String.t(),
    session_key: integer(),
    team_colour: String.t(),
    team_name: String.t()
  }

  @typedoc """
  Meeting (Grand Prix or testing weekend) information.
  """
  @type meeting :: %{
    optional(atom()) => term(),
    circuit_key: integer(),
    circuit_short_name: String.t(),
    country_code: String.t(),
    country_key: integer(),
    country_name: String.t(),
    date_start: String.t(),
    gmt_offset: String.t(),
    location: String.t(),
    meeting_key: integer(),
    meeting_name: String.t(),
    meeting_official_name: String.t(),
    year: integer()
  }

  @typedoc """
  Session (practice, qualifying, race, etc.) information.
  """
  @type session :: %{
    optional(atom()) => term(),
    circuit_key: integer(),
    circuit_short_name: String.t(),
    country_code: String.t(),
    country_key: integer(),
    country_name: String.t(),
    date_end: String.t(),
    date_start: String.t(),
    gmt_offset: String.t(),
    location: String.t(),
    meeting_key: integer(),
    session_key: integer(),
    session_name: String.t(),
    session_type: String.t(),
    year: integer()
  }

  @typedoc """
  Individual lap information.
  """
  @type lap :: %{
    optional(atom()) => term(),
    date_start: String.t(),
    driver_number: integer(),
    duration_sector_1: float() | nil,
    duration_sector_2: float() | nil,
    duration_sector_3: float() | nil,
    i1_speed: integer() | nil,
    i2_speed: integer() | nil,
    is_pit_out_lap: boolean(),
    lap_duration: float() | nil,
    lap_number: integer(),
    meeting_key: integer(),
    segments_sector_1: list(integer()) | nil,
    segments_sector_2: list(integer()) | nil,
    segments_sector_3: list(integer()) | nil,
    session_key: integer(),
    st_speed: integer() | nil
  }

  @typedoc """
  Session result (standings after a session).
  """
  @type session_result :: %{
    optional(atom()) => term(),
    dnf: boolean(),
    dns: boolean(),
    dsq: boolean(),
    driver_number: integer(),
    duration: float() | list(float()),
    gap_to_leader: float() | String.t() | list(float() | String.t()),
    number_of_laps: integer(),
    meeting_key: integer(),
    position: integer(),
    session_key: integer()
  }

  @typedoc """
  Car data (telemetry) at a sample rate of about 3.7 Hz.
  """
  @type car_data :: %{
    optional(atom()) => term(),
    brake: integer(),
    date: String.t(),
    driver_number: integer(),
    drs: integer(),
    meeting_key: integer(),
    n_gear: integer(),
    rpm: integer(),
    session_key: integer(),
    speed: integer(),
    throttle: integer()
  }

  @typedoc """
  Interval data between drivers and gap to leader.
  """
  @type interval :: %{
    optional(atom()) => term(),
    date: String.t(),
    driver_number: integer(),
    gap_to_leader: float() | String.t() | nil,
    interval: float() | String.t() | nil,
    meeting_key: integer(),
    session_key: integer()
  }

  @typedoc """
  Car location on the circuit (3D coordinates).
  """
  @type location :: %{
    optional(atom()) => term(),
    date: String.t(),
    driver_number: integer(),
    meeting_key: integer(),
    session_key: integer(),
    x: integer(),
    y: integer(),
    z: integer()
  }

  @typedoc """
  Pit stop information.
  """
  @type pit :: %{
    optional(atom()) => term(),
    date: String.t(),
    driver_number: integer(),
    lap_number: integer(),
    meeting_key: integer(),
    pit_duration: float(),
    session_key: integer()
  }

  @typedoc """
  Driver position throughout a session.
  """
  @type position :: %{
    optional(atom()) => term(),
    date: String.t(),
    driver_number: integer(),
    meeting_key: integer(),
    position: integer(),
    session_key: integer()
  }

  @typedoc """
  Race control events (flags, safety car, incidents, etc.).
  """
  @type race_control :: %{
    optional(atom()) => term(),
    category: String.t(),
    date: String.t(),
    driver_number: integer() | nil,
    flag: String.t() | nil,
    lap_number: integer() | nil,
    meeting_key: integer(),
    message: String.t(),
    scope: String.t(),
    sector: integer() | nil,
    session_key: integer()
  }

  @typedoc """
  Stint information (period of continuous driving with same tyres).
  """
  @type stint :: %{
    optional(atom()) => term(),
    compound: String.t(),
    driver_number: integer(),
    lap_end: integer(),
    lap_start: integer(),
    meeting_key: integer(),
    session_key: integer(),
    stint_number: integer(),
    tyre_age_at_start: integer()
  }

  @typedoc """
  Team radio communication.
  """
  @type team_radio :: %{
    optional(atom()) => term(),
    date: String.t(),
    driver_number: integer(),
    meeting_key: integer(),
    recording_url: String.t(),
    session_key: integer()
  }

  @typedoc """
  Weather data (updated every minute).
  """
  @type weather :: %{
    optional(atom()) => term(),
    air_temperature: float(),
    date: String.t(),
    humidity: integer(),
    meeting_key: integer(),
    pressure: float(),
    rainfall: integer(),
    session_key: integer(),
    track_temperature: float(),
    wind_direction: integer(),
    wind_speed: float()
  }

  @typedoc """
  Overtake information (beta).
  """
  @type overtake :: %{
    optional(atom()) => term(),
    date: String.t(),
    meeting_key: integer(),
    overtaken_driver_number: integer(),
    overtaking_driver_number: integer(),
    position: integer(),
    session_key: integer()
  }

  @typedoc """
  Starting grid position (beta).
  """
  @type starting_grid :: %{
    optional(atom()) => term(),
    driver_number: integer(),
    lap_duration: float(),
    meeting_key: integer(),
    position: integer(),
    session_key: integer()
  }
end
