# F1 Grid Watcher

A Phoenix application that allows you to view current F1 standings and race results. Built with Elixir and Phoenix Framework, F1 Grid Watcher provides an interactive interface to explore Formula 1 data.

## Features

### Current

- **Race Results Carousel**: View the results of the last 3 races in an interactive swiper
- **Driver Information**: See driver details including names, teams, and positions
- **Team Branding**: Visual display with team colors and logos
- **Responsive Design**: Built with TailwindCSS for a modern, responsive UI

### Planned

- **Year Selection**: Browse meetings and races by year
- **Detailed Race Views**: Open specific race endpoints to view comprehensive results
- **Enhanced Filtering**: Filter by driver, team, circuit, and more

## Data Source

All F1 data is sourced from the [OpenF1 API](https://openf1.org/), providing real-time and historical Formula 1 information.

## Getting Started

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Technology Stack

- **Backend**: Elixir with Phoenix Framework
- **Frontend**: Phoenix LiveView, TailwindCSS
- **API Client**: Custom OpenF1 API client with error handling
- **Carousel**: Swiper.js for interactive race result display

## Project Structure

```text
lib/
├── f1_grid_watcher/
│   ├── openf1/          # OpenF1 API client modules
│   │   ├── client.ex    # HTTP client with request handling
│   │   ├── meetings.ex  # Meeting/race data endpoints
│   │   └── sessions.ex  # Session data endpoints
│   └── utils.ex         # Utility functions (date formatting, logos, etc.)
├── f1_grid_watcher_web/
│   ├── controllers/     # Page controllers and templates
│   └── components/      # Reusable UI components
```

## API Integration

The application uses a modular API client structure:

- `Client.list_item/2` - Generic endpoint querying with parameter support
- Automatic query parameter building and error handling
- Response caching for improved performance
- Comprehensive logging for debugging

## Learn more

- Official website: <https://www.phoenixframework.org/>
- Guides: <https://hexdocs.pm/phoenix/overview.html>
- Docs: <https://hexdocs.pm/phoenix>
- Forum: <https://elixirforum.com/c/phoenix-forum>
- Source: <https://github.com/phoenixframework/phoenix>
