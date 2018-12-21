defmodule XUber.PickupSupervisor do
  use DynamicSupervisor

  alias XUber.{
    DB,
    Driver,
    Pickup
  }

  @name __MODULE__

  def start_link(_),
    do: DynamicSupervisor.start_link(__MODULE__, :ok, name: @name)

  def init(:ok),
    do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_child(driver, passenger, request) do
    {:ok, user} = Driver.get_user(driver)
    {:ok, pickup} = DB.create_pickup(request, user.name)

    DynamicSupervisor.start_child(@name, {Pickup, [driver, passenger, pickup]})
  end
end
