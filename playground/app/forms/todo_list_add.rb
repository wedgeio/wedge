class TodoListAddForm < Wedge::Plugins::Form
  name :todo_list_add

  attr_accessor :description

  def validate
    assert_present :description
  end
end
