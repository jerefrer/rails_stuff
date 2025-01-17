require 'integration_helper'

RSpec.describe Site::ProjectsController, :db_cleaner, type: :controller do
  let(:user) { User.create_default! }
  let(:resource) { Project.create_default!(user: user) }
  let(:other_user) { User.create_default! }
  let(:other_resource) { Project.create_default!(user: other_user) }
  let(:controller_resource) { controller.send :resource }

  describe '#index' do
    subject { get :index, user_id: user.id }
    before { resource && other_resource }

    it 'renders index, and limits collection to parent`s resources' do
      should render_template :index
      expect(controller.send(:collection).all.to_a).to eq [resource]
    end

    context 'when pagination params are given' do
      subject { get :index, user_id: user.id, page: 10, per: 2 }
      it 'paginates collection' do
        should render_template :index
        collection = controller.send(:collection)
        expect(collection.offset_value).to eq 18
        expect(collection.limit_value).to eq 2
      end
    end

    context 'when parent is not found' do
      subject { get :index, user_id: -1 }
      render_views
      it { should be_not_found }
    end
  end

  describe '#create' do
    subject { post :create, user_id: user.id, project: resource_params }
    let(:resource_params) do
      {
        name: 'New project',
        user_id: other_user.id,
        department: 'D',
        company: 'C',
        type: 'Project::Internal',
      }
    end

    context 'when create succeeds' do
      it 'redirects to created user path' do
        expect { should be_redirect }.to change { user.projects.count }.by(1)
        resource = user.projects.last
        expect(resource.attributes).to include(
          'name' => 'New project',
          'department' => 'D',
          'company' => nil,
        )
        should redirect_to site_user_projects_path(user)
      end

      it 'respects per-type allowed attributes' do
        resource_params[:type] = 'Project::External'
        should redirect_to site_user_projects_path(user)
        expect(user.projects.last.attributes).to include(
          'name' => 'New project',
          'department' => nil,
          'company' => 'C',
        )
      end
    end

    context 'when create fails' do
      let(:resource_params) { super().except(:name) }

      it 'renders index' do
        expect { should render_template :index }.to_not change(Project, :count)
        expect(controller_resource.attributes).to include(
          'user_id' => user.id,
          'name' => nil,
          'department' => 'D',
          'company' => nil,
        )
      end
    end

    context 'when invalid type is requested' do
      let(:resource_params) { super().merge(type: 'Project::Hidden') }
      it { should be_not_found }
    end

    context 'when parent is not found' do
      subject { post :create, user_id: -1, project: {type: 'Project::External'} }
      it { should be_not_found }
    end
  end

  describe '#update' do
    subject { patch :update, id: resource.id, project: resource_params }
    let(:resource_params) do
      {
        name: 'New project',
        user_id: other_user.id,
        department: 'D',
        company: 'C',
        type: 'Project::Hidden',
      }
    end

    context 'when update succeeds' do
      it 'redirects to index' do
        expect { should be_redirect }.
          to change { resource.reload.attributes.slice(*%w(name department company type)) }.
          to(
            'name' => 'New project',
            'department' => nil,
            'company' => 'C',
            'type' => 'Project::External',
          )
        should redirect_to site_user_projects_path(user)
      end

      context 'when resource is of other type' do
        let(:resource) { super().becomes!(Project::Internal).tap(&:save!) }

        it 'respects per-type allowed attributes' do
          expect { should redirect_to site_user_projects_path(user) }.
            to change { resource.reload.attributes.slice(*%w(name department company type)) }.
            to(
              'name' => 'New project',
              'department' => 'D',
              'company' => nil,
              'type' => 'Project::Internal',
            )
        end
      end
    end

    context 'when update fails' do
      let(:resource_params) { super().merge(name: '') }

      it 'renders edit' do
        expect { should render_template :edit }.
          to_not change { resource.reload.attributes }
        expect(controller_resource.attributes).to include(
          'user_id' => user.id,
          'name' => '',
          'department' => nil,
          'company' => 'C',
          'type' => 'Project::External',
        )
      end
    end
  end
end
