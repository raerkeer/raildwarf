defmodule UiWeb.PageLive do
  use UiWeb, :live_view

  @refresh_interval_ms 1000

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(current_time_second: System.monotonic_time(:second))
      |> assign(serial_number: get_serial_number())
      |> assign(speed: Loco.get)

    if connected?(socket) do
      schedule_refresh()
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, socket) do
    schedule_refresh()
    socket =
      socket
      |> assign(current_time_second: System.monotonic_time(:second))
      |> assign(speed: Loco.get)

    {:noreply, socket}
  end

  #range 50000 - 75000 - 100000 (delta 25000)
  @impl true
  def handle_event("stop", _value, socket) do
    Loco.set(:stop)
    {:noreply, socket}
  end

  @impl true
  def handle_event("inc", _value, socket) do
    Loco.set(:acc)
    {:noreply, socket}
  end

  @impl true
  def handle_event("dec", _value, socket) do
    Loco.set(:dec)
    {:noreply, socket}
  end

  defp schedule_refresh() do
    Process.send_after(self(), :tick, @refresh_interval_ms)
  end

  defp get_serial_number() do
    case Code.ensure_loaded(Nerves.Runtime) do
      {:module, _} -> Nerves.Runtime.serial_number()
      _error -> "Unavailable"
    end
  end
end