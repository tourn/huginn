require 'feedjira'

module FeedjiraExtension
  LINK_ATTRS = %i[href rel type hreflang title length]
  ENCLOSURE_ATTRS = %i[url type length]

  class AtomAuthor
    include SAXMachine

    element :name
    element :email
    element :uri
  end

  class Enclosure
    include SAXMachine

    ENCLOSURE_ATTRS.each do |attr|
      attribute attr
    end

    def to_json(options = nil)
      ENCLOSURE_ATTRS.each_with_object({}) { |key, hash|
        if value = __send__(key)
          hash[key] = value
        end
      }.to_json(options)
    end
  end

  class AtomLink
    include SAXMachine

    LINK_ATTRS.each do |attr|
      attribute attr
    end

    def to_json(options = nil)
      LINK_ATTRS.each_with_object({}) { |key, hash|
        if value = __send__(key)
          hash[key] = value
        end
      }.to_json(options)
    end
  end

  class RssLinkElement
    include SAXMachine

    value :href

    def to_json(options = nil)
      {
        href: href
      }.to_json(options)
    end
  end

  module HasEnclosure
    def self.included(mod)
      mod.module_exec do
        sax_config.top_level_elements['enclosure'].clear

        element :enclosure, class: Enclosure

        def image_enclosure
          case enclosure.try!(:type)
          when %r{\Aimage/}
            enclosure
          end
        end

        def image
          @image ||= image_enclosure.try!(:url)
        end
      end
    end
  end

  module HasLinks
    def self.included(mod)
      mod.module_exec do
        sax_config.top_level_elements['link'].clear
        sax_config.collection_elements['link'].clear

        case name
        when /RSS/
          elements :link, class: RssLinkElement, as: :rss_links

          case name
          when /FeedBurner/
            elements :'atok10:link', class: AtomLink, as: :atom_links

              def links
                @links ||= [*rss_links, *atom_links]
              end
          else
            alias_method :links, :rss_links
          end
        else
          elements :link, class: AtomLink, as: :links
        end

        def alternate_link
          links.find { |link|
            link.is_a?(AtomLink) &&
              link.rel == 'alternate' &&
              (link.type == 'text/html'|| link.type.nil?)
          }
        end

        def url
          @url ||= (alternate_link || links.first).try!(:href)
        end
      end
    end
  end

  module FeedEntryExtensions
    def self.included(mod)
      mod.module_exec do
        include HasEnclosure
        include HasLinks
      end
    end
  end

  module FeedExtensions
    def self.included(mod)
      mod.module_exec do
        include HasEnclosure
        include HasLinks

        element  :id, as: :feed_id
        element  :generator
        elements :rights
        element  :published
        element  :updated
        element  :icon
        elements :author, class: AtomAuthor, as: :authors

        if /RSS/ === name
          element :guid, as: :feed_id
          element :managingEditor
          element :pubDate, as: :published
          element :'dc:date', as: :published
          element :lastBuildDate, as: :updated
          element :image, value: :url, as: :icon
        end

        sax_config.collection_elements.each_value do |collection_elements|
          collection_elements.each do |collection_element|
            collection_element.accessor == 'entries' &&
              (entry_class = collection_element.data_class).is_a?(Class) or next

            entry_class.send :include, FeedEntryExtensions
          end
        end
      end
    end
  end

  Feedjira::Feed.feed_classes.each do |feed_class|
    feed_class.send :include, FeedExtensions
  end
end
