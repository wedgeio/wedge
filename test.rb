require 'awesome_print'

requires = {
  form_plugin: [],
  list: [
    {
      name: 'claim',
      requires: [
        {name: 'filter_form', requires: [{ name: 'form_plugin', requires: [] }]},
        {name: 'claim_form', requires: []}
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

$loaded_requires = []

def get_requires reqs, requires_array = []
  new_reqs = []

  reqs.each do |r|
    if r[:requires].any?
      get_requires(r[:requires], requires_array)
    end

    unless $loaded_requires.include? r[:name]
      $loaded_requires << r[:name]
      new_reqs         << r[:name]
    end
  end

  requires_array << new_reqs if new_reqs.any?

  requires_array
end

ap get_requires requires[:list]
