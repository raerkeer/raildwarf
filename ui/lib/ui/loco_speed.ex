defmodule LocoSpeed do
  use GenServer

  @gpio_pin 12
  @pwm_frequency 50
  @pwm_neutral 75000
  @pwm_max 100000
  @pwm_min 50000

  # Client
  def start_link(_default) do
    GenServer.start_link(__MODULE__, %Speed{}, name: LocoSpeedServer)
  end

  def set(action) do
    GenServer.cast(LocoSpeedServer, action)
  end

  def get do
    GenServer.call(LocoSpeedServer, :get_speed)
  end

  def set_speeds(%LocoConfig{} = settings) do
    GenServer.cast(LocoSpeedServer, settings)
  end

  # Server Callbacks
  @impl true
  def init(speed) do
    set_pwm(speed)
    {:ok, speed}
  end

  @impl true
  def handle_call(:get_speed, _from, speed) do
    percent =
    cond do
      speed.current > @pwm_neutral -> -(speed.current - @pwm_neutral) / 250
      speed.current < @pwm_neutral -> (@pwm_neutral - speed.current) / 250
      speed.current == @pwm_neutral -> 0
    end

    {:reply, percent, speed}
  end

  @impl true
  def handle_cast(%LocoConfig{} = settings, speed) do
    new_speed = %{speed | neg4: settings.neg4, neg3: settings.neg3, neg2: settings.neg2, neg1: settings.neg1, pos1: settings.pos1, pos2: settings.pos2, pos3: settings.pos3, pos4: settings.pos4}
    {:noreply, new_speed}
  end

  @impl true
  def handle_cast(:acc, old_speed) do
    new_speed = Speed.next_target(old_speed)
    schedule_speed()
    {:noreply, new_speed}
  end

  @impl true
  def handle_cast(:dec, old_speed) do
    new_speed = Speed.prev_target(old_speed)
    schedule_speed()
    {:noreply, new_speed}
  end

  @impl true
  def handle_cast(:stop, old_speed) do
    new_speed = Speed.stop(old_speed)
    schedule_speed()
    {:noreply, new_speed}
  end

  @impl true
  def handle_info(:schedule_speed, %Speed{current: old_speed, target: target_speed} = speed) when target_speed == old_speed do
    {:noreply, speed}
  end
  def handle_info(:schedule_speed, %Speed{} = speed) do
    new_speed = Speed.next_speed(speed)

    set_pwm(new_speed)

    schedule_speed()

    {:noreply, new_speed}
  end

  defp schedule_speed() do
    Process.send_after(self(), :schedule_speed, 20)
  end

  defp set_pwm(%Speed{current: current}) do
    if unquote(Mix.env == :prod) do
      Pigpiox.Pwm.hardware_pwm(@gpio_pin, @pwm_frequency, current)
    end
  end

end
