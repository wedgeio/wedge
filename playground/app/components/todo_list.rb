require_relative '../forms/todo_list_add'

class Playground
  class TodoListComponent < Wedge::Component
    name :todo_list
    html 'public/todo_list.html'

    def display
      wedge(:layout).display(body_class: 'todo_list') { dom } if server?
    end

    on :submit, '#add-form', key: :todo, form: :todo_list_add do |form, el|
      button = el.find('button[type="submit"]')
      button.prop("disabled", true)
      if form.valid?
        puts 'valid'
      else
        form.display_errors
        button.prop("disabled", false)
        puts 'errors'
      end
    end
  end
end
