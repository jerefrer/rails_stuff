require 'rails_helper'
require 'support/active_record'

RSpec.describe RailsStuff::SortScope do
  describe '.filter_param' do
    def assert_filter(expected, val = nil, default = nil, allowed = [], params = {})
      result = described_class.filter_param(val, params, allowed, default)
      expect(result).to eq expected
    end

    def assert_default(val = nil, allowed = [])
      assert_filter(nil,          val, nil,         allowed)
      assert_filter({id: :desc},  val, {id: :desc}, allowed)
      assert_filter({id: :asc},   val, {id: :asc},  allowed, sort_desc: true)
      assert_filter({id: :asc},   val, :id,         allowed)
      assert_filter({id: :desc},  val, :id,         allowed, sort_desc: true)
      assert_filter({id: :desc},  val, :id,         allowed, sort_desc: 'true')
      assert_filter({id: :desc},  val, :id,         allowed, sort_desc: '1')
      assert_filter({id: :asc},   val, :id,         allowed, sort_desc: 'false')
      assert_filter({id: :asc},   val, :id,         allowed, sort_desc: '0')
    end

    let(:allowed) { [:id, :name] }

    context 'when val is not set' do
      it 'returns default' do
        assert_default
      end
    end

    context 'when val is scalar' do
      context 'and is not allowed' do
        it 'returns default' do
          assert_default(:lastname, allowed)
        end
      end

      it 'returns hash based on it' do
        assert_filter({name: :asc},   :name, nil, allowed)
        assert_filter({name: :desc},  :name, nil, allowed, sort_desc: true)
      end
    end

    context 'when val is a hash' do
      it 'slices only allowed keys' do
        assert_filter({},             {lastname: 'desc', parent: 'asc'},    nil, allowed)

        assert_filter({name: :desc},  {name: 'desc', parent: 'asc'},        nil, allowed)
        assert_filter({name: :asc},   {name: 'asc', parent: 'asc'},         nil, allowed)
        assert_filter({name: :asc},   {name: {smt: :else}, parent: 'asc'},  nil, allowed)

        assert_filter(
          {name: :desc, id: :desc},
          {name: 'desc', id: 'desc', parent: 'asc'},
          nil,
          allowed
        )
        assert_filter(
          {name: :asc,  id: :desc},
          {name: 'sc',  id: 'desc', parent: 'asc'},
          nil,
          allowed
        )
      end
    end
  end

  describe '.has_sort_scope' do
    let(:controller_class) do
      described_class = self.described_class
      Class.new(ActionController::Base) do
        extend described_class

        def action_name
          :index
        end
      end
    end
    let(:controller) { controller_class.new }
    let(:model) { Class.new(ActiveRecord::Base) { self.table_name = :users } }

    def assert_sort_query(expected, **params)
      allow(controller).to receive(:params) do
        ActionController::Parameters.new(params.as_json)
      end
      sql = controller.send(:apply_scopes, model).order_values.map(&:to_sql).join("\n")
      expect(sql).to eq expected
    end

    context 'when sorting by multiple fields is allowed' do
      before { controller_class.has_sort_scope by: [:id, :package_name] }

      it 'applies all scopes' do
        assert_sort_query %("users"."package_name" DESC\n"users"."id" ASC),
          sort: {package_name: :desc, id: :asc, qqq: :desc}
      end
    end

    context 'when called multiple times' do
      before { controller_class.has_sort_scope by: :id }
      before { controller_class.has_sort_scope by: :package_name }

      it 'applies all scopes' do
        assert_sort_query %("users"."id" ASC\n"users"."package_name" DESC),
          sort: {package_name: :desc, id: :asc, qqq: :desc}
      end
    end

    context 'accepts default value' do
      before { controller_class.has_sort_scope by: [:id], default: :package_name }

      it 'and uses it' do
        assert_sort_query '"users"."package_name" ASC'
        assert_sort_query '"users"."package_name" DESC', sort_desc: true
        assert_sort_query '"users"."package_name" ASC', sort: :qqq
      end
    end
  end
end
