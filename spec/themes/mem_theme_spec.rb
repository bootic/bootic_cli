require 'spec_helper'
require 'bootic_cli/themes/mem_theme'

describe BooticCli::Themes::MemTheme do
  subject { described_class.new }

  it "implements the generic Theme interface" do
    subject.add_template "layout.html", "foo"
    subject.add_template "master.css", "bar"
    subject.add_template "master.css", "bar" # add again
    subject.add_asset "icon.gif", StringIO.new("")
    subject.add_asset "icon.gif", StringIO.new("") # add again

    expect(subject.templates.size).to eq 2
    expect(subject.assets.size).to eq 1

    it_is_a_template(subject.templates.first, file_name: 'layout.html')
    it_is_a_template(subject.templates.last, file_name: 'master.css')
    it_is_an_asset(subject.assets.first, file_name: 'icon.gif')

    subject.remove_template "layout.html"
    subject.remove_asset "icon.gif"

    expect(subject.templates.size).to eq 1
    expect(subject.assets.size).to eq 0
  end
end
