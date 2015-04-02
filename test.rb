requires = {
  form_plugin: [],
  list: [
    {
      name: 'claim',
      requires: [
        {name: 'filter_form', requires: [{ name: 'form_plugin', requires: [] }]}
      ],
    },
    {
      name: 'claim_form',
      requires: [
        {name: 'form_plugin', requires: []},
        {name: 'address_form', requires: [{ name: 'form_plugin', requires: [] }]}
      ],
    }
  ]
}

def get_requires reqs
  reqs.each do |r|
    if r[:requires].any?
      get_requires r[:requires]
      puts r[:name]
    else
      puts r[:name]
    end
  end
end

get_requires requires[:list]
