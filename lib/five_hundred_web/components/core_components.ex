defmodule FiveHundredWeb.CoreComponents do
  use Phoenix.Component

  # Import required functions
  import Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @doc """
  Renders an error message for form inputs.
  """
  attr :form, :any, required: true
  attr :field, :atom, required: true

  def error_tag(assigns) do
    ~H"""
    <%= for error <- Keyword.get_values(@form.errors, @field) do %>
      <span class="invalid-feedback" phx-feedback-for={input_name(@form, @field)}>
        <%= translate_error(error) %>
      </span>
    <% end %>
    """
  end

  @doc """
  Renders a form label with consistent styling.
  """
  attr :for, :any, required: true
  slot :inner_block, required: true

  def form_label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium text-gray-700">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders an input with label and error messages.
  """
  attr :field, Phoenix.HTML.FormField
  attr :type, :string, default: "text"
  attr :class, :string, default: ""
  attr :value, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete disabled readonly)

  def input(assigns) do
    assigns = assign_new(assigns, :value, fn -> input_value(assigns.field.form, assigns.field.field) end)
    
    ~H"""
    <%= text_input @field, type: @type, class: @class, value: @value, name: input_name(@field.form, @field.field) %>
    """
  end

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button type={@type} class={@class}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  # Add any core components you need here
  # This is a minimal example - you can add more components as needed
  
  @doc """
  Renders a modal.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label="close"
                >
                  ✖
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.
  """
  attr :flash, :map, default: %{}
  attr :kind, :atom, values: [:info, :error], doc: "used for styling"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  def flash(%{kind: :info} = assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      role="alert"
      class="fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg bg-emerald-50 p-3 ring-1 ring-emerald-500 shadow-md"
      {@rest}
    >
      <p class="flex items-center gap-1.5 text-sm text-emerald-800">
        <%= msg %>
      </p>
    </div>
    """
  end

  def flash(%{kind: :error} = assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      role="alert"
      class="fixed top-2 right-2 w-80 sm:w-96 z-50 rounded-lg bg-rose-50 p-3 ring-1 ring-rose-500 shadow-md"
      {@rest}
    >
      <p class="flex items-center gap-1.5 text-sm text-rose-900">
        <%= msg %>
      </p>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  ## JS Commands

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.pop_focus()
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end