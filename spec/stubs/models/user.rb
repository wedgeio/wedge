unless RUBY_ENGINE == 'opal'
  class Playground
    class User
      class << self
        def find id
          if id == 1
            {id: 1, first_name: 'Test', last_name: 'Admin', is_admin: true, secret_key: 123456}
          else
            nil
          end
        end
      end
    end
  end
end
