Factory.define(:asset_link, class: AssetsLink) do |f|
  f.url "http://www.slack.com/"
  f.link_type AssetsLink::DISCUSSION
  f.association :asset, factory: :model
end