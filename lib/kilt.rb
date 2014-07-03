require "kilt/base"
require_relative "kilt_object"

# Include the Rethink shortcut module, which will among other things instantiate a new
# Rethink object (as "r") if needed
include RethinkDB::Shortcuts

module Kilt
  
  # Hold the config object
  mattr_accessor :config
  
  # Auto-generated endpoints
  def self.method_missing(method, *args)
    begin
      
      if Utils.is_singular? method.to_s
        # Get the configuration for a type
        # Example: Kilt.event
        Kilt.config.objects[method]
      else
        # Get a list of objects
        # Example: Kilt.events
        Kilt.get_collection method.to_s 
      end
    end
  end
  
  # Get the list of types
  # Returns: array of type names
  # Example: Kilt.types
  def self.types
    Kilt.config.objects.map { |key, value| key.to_s }
  end
  
  
  # Create an object
  # Returns: boolean
  # Example: Kilt.create(object)
  def self.create(object)
    object['created_at'] = object['updated_at'] = Time.now
    object['unique_id']  = "#{(Time.now.to_f * 1000).to_i}"
    object['type']       = object.instance_eval { @type }
    object['slug']       = slug_for object

    Utils.database.create object
  end

  # Update an object
  # Returns: boolean
  # Example: Kilt.update(object)
  def self.update(slug, object)
    object['updated_at'] = Time.now
    object['slug']       = slug_for object

    Utils.database.update object
  end

  # Delete an object
  # Returns: boolean
  # Example: Kilt.delete('some-object')
  def self.delete(slug)
    Utils.database.delete slug
  end

  # Get the content for a specific object
  # Returns: Kilt::Object instance
  # Example: Kilt.object('big-event')
  def self.get(slug)
    result = Utils.database.find(slug)
    result ? Kilt::Object.new(result['type'], result)
           : nil
  end
  
  # Get a list of objects
  # Returns: array of hashes
  # Example: Kilt.objects('events')
  # Used directly or via method_missing
  def self.get_collection(object_type)
    results = Utils.database.find_all_by_type object_type
    Kilt::ObjectCollection.new results
  end

  class << self

    private

    def slug_is_unique_for? slug, object
      result = Utils.database.find(slug)
      return true if result.nil?

      "#{result['unique_id']}" == "#{object['unique_id']}"
    end

    def slug_for object
      slug = possibly_duplicate_slug_for object
      slug_is_unique_for?(slug, object) ? slug
                                        : make_slug_unique(slug)
    end

    def make_slug_unique slug
      "#{slug}-#{(Time.now.to_f * 1000).to_i}"
    end

    def possibly_duplicate_slug_for object
      if object['slug'].to_s.strip == ''
        if prefix = prefix_for(object)
          "#{prefix}-#{slugified_value_for(object)}"
        else
          slugified_value_for(object)
        end
      else
        "#{object['slug']}"
      end
    end

    def slugified_value_for object
      Utils.slugify(object['name'])
    end

    def prefix_for object
      return nil unless prefix = lookup_the_suggested_prefix_for(object)
      slug = slugified_value_for object
      slug.starts_with?(prefix) && slug != prefix ? nil
                                                  : prefix
    end

    def lookup_the_suggested_prefix_for object
      Kilt.send(object['type'].to_sym)['slug_prefix']
    end

  end

end

