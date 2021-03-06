require "spoved/logger"
require "./error"
require "./interfaces/i_group"
require "./events"
require "./helpers/entities"

module Entitas
  class Group(TEntity)
    include Entitas::IGroup
    include Entitas::Helper::Entities(TEntity)

    protected property single_entitie_cache : TEntity?
    protected property to_string_cache : String?

    def initialize(@matcher : Entitas::Matcher)
    end

    # This is used by the context to manage the group.
    def handle_entity_silently(entity : IEntity)
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Silently handling entity : #{entity}" }{% end %}

      if self.matcher.matches?(entity)
        add_entity_silently(entity)
      else
        remove_entity_silently(entity)
      end
    end

    def handle_entity(entity : IEntity) : Entitas::Events::GroupChanged
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Handling entity : #{entity}" }{% end %}

      if self.matcher.matches?(entity)
        add_entity_silently(entity) ? Entitas::Events::OnEntityAdded : nil
      else
        remove_entity_silently(entity) ? Entitas::Events::OnEntityRemoved : nil
      end
    end

    # This is used by the context to manage the group.
    def handle_entity(entity : IEntity, index : Int32, component : Entitas::IComponent)
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Context handle entity : #{entity}" }{% end %}

      if self.matcher.matches?(entity)
        add_entity(entity, index, component)
      else
        remove_entity(entity, index, component)
      end
    end

    # This is used by the context to manage the group.
    def update_entity(entity : IEntity, index : Int32, prev_component : Entitas::IComponent?, new_component : Entitas::IComponent?)
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Update entity : #{entity}" }{% end %}

      if has_entity?(entity)
        emit_event OnEntityRemoved, self, entity, index, prev_component
        emit_event OnEntityAdded, self, entity, index, new_component
        emit_event OnEntityUpdated, self, entity, index, prev_component, new_component
      end
    end

    # Removes all event handlers from this group.
    # Keep in mind that this will break reactive systems and
    # entity indices which rely on this group.
    #
    # Removes: `OnEntityRemoved`, `OnEntityAdded`, and `OnEntityUpdated`
    def remove_all_event_handlers
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Remove all event handlers" }{% end %}

      self.clear_on_entity_removed_event_hooks
      self.clear_on_entity_added_event_hooks
      self.clear_on_entity_updated_event_hooks
    end

    def add_entity_silently(entity : TEntity) : TEntity | Bool
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Silently adding entity : #{entity}" }{% end %}

      if entity.enabled? && self.entities.add?(entity)
        self.entities_cache = nil
        self.single_entitie_cache = nil
        entity.retain(self)

        return entity
      end

      false
    end

    def add_entity(entity : Entity, index : Int32, component : Component)
      {% if flag?(:entitas_enable_logging) %}Log.warn { "#{self} - Adding entity : #{entity}" }{% end %}
      if add_entity_silently(entity)
        emit_event OnEntityAdded, self, entity, index, component
      end
    end

    private def _remove_entity(entity : Entity)
      self.entities.delete(entity)
      self.entities_cache = nil
      self.single_entitie_cache = nil
    end

    def remove_entity_silently(entity : Entity) : Entity?
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Silently removing entity : #{entity}" }{% end %}

      if self.has_entity?(entity)
        self._remove_entity(entity)

        entity.release(self)
        entity
      else
        nil
      end
    end

    def remove_entity(entity : Entity, index : Int32, component : Component) : Entity?
      {% if flag?(:entitas_enable_logging) %}Log.debug { "#{self} - Removing entity : #{entity}" }{% end %}

      if self.has_entity?(entity)
        self._remove_entity(entity)

        emit_event OnEntityRemoved, self, entity, index, component

        entity.release(self)
        entity
      else
        nil
      end
    end

    def get_entities(buff : Enumerable(IEntity))
      buff.clear
      buff.concat entities
      buff
    end

    # Returns the only entity in this group. It will return null
    # if the group is empty. It will throw an exception if the group
    # has more than one entity.
    def get_single_entity : Entitas::IEntity?
      if single_entitie_cache.nil?
        if size == 1
          self.single_entitie_cache = entities.first?
        elsif size == 0
          return nil
        else
          raise Entitas::Group::Error::SingleEntity.new
        end
      end

      single_entitie_cache
    end

    ############################
    # Misc funcs
    ############################

    def to_s(io)
      io << "Group("
      matcher.to_s(io)
      io << ")"
    end

    def to_json(json)
      json.object do
        json.field "matcher", matcher
        json.field "entities", get_entities
      end
    end
  end
end
