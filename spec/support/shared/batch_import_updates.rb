require 'spec_helper'

shared_examples 'an import happy path' do
  it 'assigns @batch' do
    expect(assigns[:batch].id).to eq batch.id
  end

  it 'HTML response redirects to batch show page' do
    expect(response).to redirect_to(batch_path(batch))
  end

  it 'adds an audit log' do
    expect(TuftsPdf.first.audit_log.who).to include @user.user_key
  end

  it 'attaches the files to the records' do
    pdf = TuftsPdf.first.datastreams['Archival.pdf']
    expect(pdf.has_content?).to be_true
    expect(pdf.mimeType).to eq file1.content_type
  end

  it 'adds new PIDs without deleting existing PIDs' do
    expected_pids = TuftsPdf.all.map(&:pid) + ['oldpid:123']
    expect(assigns[:batch].pids.sort).to eq expected_pids.sort
  end

  it 'adds the batch id to the new records' do
    TuftsPdf.all.each do |pdf|
      expect(pdf.batch_id).to eq [assigns[:batch].id.to_s]
    end
  end
end

shared_examples 'an import error path (no documents uploaded)' do
  before do
    patch :update, id: batch.id, documents: []
  end

  it 'renders the form' do
    response.should render_template(:edit)
  end

  it 'displays a flash message' do
    expect(flash[:error]).to match /please select some files/i
  end

  it 'assigns @batch' do
    expect(assigns[:batch].id).to eq batch.id
  end
end

shared_examples 'an import error path (wrong file format)' do
  before do
    TuftsPdf.delete_all
    allow_any_instance_of(TuftsPdf).to receive(:valid_type_for_datastream?) { false }
    patch :update, id: batch.id, documents: [file1]
  end

  it 'displays a warning message, but still creates the record' do
    expect(TuftsPdf.count).to eq 1
    record = TuftsPdf.first
    expect(assigns[:batch].pids.sort).to eq [record.pid, 'oldpid:123'].sort
    expect(flash[:alert]).to match /#{file1.content_type} file, which is not a valid type: #{file1.original_filename}/i
  end
end

shared_examples 'an import error path (failed to save batch)' do
  before do
    allow(Batch).to receive(:find) { batch }
    allow(batch).to receive(:save) { false }
    @batch_error = 'Batch Error 1'
    batch.errors.add(:base, @batch_error)
    patch :update, id: batch.id, documents: [file1]
  end

  it 'returns to the edit page' do
    expect(response).to render_template(:edit)
  end
end

shared_examples 'a JSON import' do
  describe 'happy path' do
    it 'redirects to get the JSON response for the new record' do
      patch :update, id: batch.id, documents: [file1], format: :json
      expect(response).to redirect_to(catalog_path(TuftsPdf.first, json_format: 'jquery-file-uploader'))
    end
  end

  describe 'error path (failed to create record)' do
    before do
      # Force creation of batch so it doesn't choke on the errors we create in TuftsPdf
      batch
      # A record with errors
      @pdf = FactoryGirl.create(:tufts_pdf)
      @error1 = 'Record error 1'
      @error2 = 'Record error 2'
      @pdf.errors.add(:base, @error1)
      @pdf.errors.add(:base, @error2)
      allow(@pdf).to receive(:valid?) { true }
      allow(@pdf).to receive(:persisted?) { false }
      allow(TuftsPdf).to receive(:new) { @pdf }

      patch :update, id: batch.id, documents: [file1], format: :json
    end

    it 'returns JSON data needed by the view template' do
      json = JSON.parse(response.body)['files'].first
      expect(json['pid']).to eq @pdf.pid
      expect(json['name']).to eq @pdf.title
      expect(json['error']).to eq [@error1, @error2]
    end
  end
end
