module QuestionQueryPatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)
    
    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      base.add_available_column(QueryColumn.new(:formatted_questions))

      
      alias_method :available_filters_before_question, :available_filters
      alias_method :available_filters, :question_available_filters

      alias_method :sql_for_field_before_question, :sql_for_field
      alias_method :sql_for_field, :question_sql_for_field
    end

  end
  
  module ClassMethods
    unless Query.respond_to?(:available_columns=)
      # Setter for +available_columns+ that isn't provided by the core.
      def available_columns=(v)
        self.available_columns = (v)
      end
    end
    
    unless Query.respond_to?(:add_available_column)
      # Method to add a column to the +available_columns+ that isn't provided by the core.
      def add_available_column(column)
        self.available_columns << (column)
      end
    end
  end
  
  module InstanceMethods
    
    # Wrapper around the +available_filters+ to add a new Question filter
    def question_available_filters
      @available_filters = available_filters_before_question
      
      user_values = []
      user_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
      if project
        user_values += project.users.sort.collect{|s| [s.name, s.id.to_s] }
      else
        user_values += User.current.projects.collect(&:users).flatten.uniq.sort.collect{|s| [s.name, s.id.to_s] }
      end

      question_filters = {
        "question_assigned_to_id" => { :type => :list, :order => 14, :values => user_values },
        "question_asked_by_id" => { :type => :list, :order => 14, :values => user_values }
      }
      
      return @available_filters.merge(question_filters)
    end
    
    # Wrapper for +sql_for_field+ so Questions can use a different table than Issues
    def question_sql_for_field(field, operator, v, db_table, db_field, is_custom_filter=false)
      if field == "question_assigned_to_id" || field == "question_asked_by_id"
        v = values_for(field).clone

        db_table = Question.table_name
        if field == "question_assigned_to_id"
          db_field = 'assigned_to_id'
        else
          db_field = 'author_id'
        end
        
        
        # "me" value subsitution
        v.push(User.current.logged? ? User.current.id.to_s : "0") if v.delete("me")
        
        case operator
        when "="
          sql = "#{db_table}.#{db_field} IN (" + v.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ") AND #{db_table}.opened = true"
        when "!"
          sql = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + v.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")) AND #{db_table}.opened = true"
        end

        return sql
        
      else
        return sql_for_field_before_question(field, operator, v, db_table, db_field, is_custom_filter)
      end
      
    end
    
  end  
end

