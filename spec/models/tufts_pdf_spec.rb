require 'spec_helper'

describe TuftsPdf do
  
  describe "with access rights" do
    before do
      @pdf = TuftsPdf.new
      @pdf.read_groups = ['public']
      @pdf.save!
    end

    after do
      @pdf.destroy
    end

    let (:ability) {  Ability.new(nil) }

    it "should be visible to a not-signed-in user" do
      ability.can?(:read, @pdf.pid).should be_true
    end
  end

end