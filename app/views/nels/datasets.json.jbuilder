json.array! @datasets do |dataset|
  json.id "dataset#{dataset['id']}"
  json.text dataset['name']
  json.parent "project#{params[:id]}"
  json.icon dataset['isLocked'] ? nels_locked_dataset_glyph : nels_dataset_glyph
  json.data do
    json.id dataset['id']
    json.project_id params[:id]
    json.is_dataset true
  end
end

@datasets.each do |dataset|
  json.array! dataset['subtypes'].split(',') do |subtype|
    json.id "#{subtype}#{dataset['id']}"
    json.text subtype
    json.parent "dataset#{dataset['id']}"
    json.icon nels_subtype_glyph
    json.data do
      json.id "#{subtype}#{dataset['id']}"
      json.project_id params[:id]
      json.dataset_id dataset['id']
      json.dataset_name dataset['name']
      json.text subtype
      json.is_subtype true
    end
  end
end