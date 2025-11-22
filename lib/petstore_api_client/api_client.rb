# frozen_string_literal: true

module PetstoreApiClient
  # Main API client - this is what users interact with
  class ApiClient
    attr_reader :configuration

    def initialize(config = nil)
      @configuration = config || Configuration.new
      @configuration.validate!
    end

    def configure
      yield(configuration) if block_given?
      # Reset clients when configuration changes
      @pet_client = nil
      @store_client = nil
      self
    end

    # Access to Pet endpoints
    def pets
      @pets ||= Clients::PetClient.new(configuration)
    end

    # Access to Store endpoints
    def store
      @store ||= Clients::StoreClient.new(configuration)
    end

    # Convenience methods so you can do client.create_pet instead of client.pets.create_pet
    def create_pet(pet_data)
      pets.create_pet(pet_data)
    end

    def get_pet(pet_id)
      pets.get_pet(pet_id)
    end

    def update_pet(pet_data)
      pets.update_pet(pet_data)
    end

    def delete_pet(pet_id)
      pets.delete_pet(pet_id)
    end

    def create_order(order_data)
      store.create_order(order_data)
    end

    def get_order(order_id)
      store.get_order(order_id)
    end

    def delete_order(order_id)
      store.delete_order(order_id)
    end
  end
end
