#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:help, '0.0.1'] do
  it "has a help action" do
    subject.should be_action :help
  end

  it "has a default action of help" do
    subject.get_action('help').should be_default
  end

  it "accepts a call with no arguments" do
    expect {
      subject.help()
    }.to_not raise_error
  end

  it "accepts a face name" do
    expect { subject.help(:help) }.to_not raise_error
  end

  it "accepts a face and action name" do
    expect { subject.help(:help, :help) }.to_not raise_error
  end

  it "fails if more than a face and action are given" do
    expect { subject.help(:help, :help, :for_the_love_of_god) }.
      to raise_error ArgumentError
  end

  it "treats :current and 'current' identically" do
    subject.help(:help, :version => :current).should ==
      subject.help(:help, :version => 'current')
  end

  it "raises an error when the face is unavailable" do
    expect {
      subject.help(:huzzah, :bar, :version => '17.0.0')
    }.to raise_error(ArgumentError, /Could not find version 17\.0\.0/)
  end

  it "finds a face by version" do
    face = Puppet::Face[:huzzah, :current]
    subject.help(:huzzah, :version => face.version).
      should == subject.help(:huzzah, :version => :current)
  end

  context "when listing subcommands" do
    subject { Puppet::Face[:help, :current].help }

    RSpec::Matchers.define :have_a_summary do
      match do |instance|
        instance.summary.is_a?(String)
      end
    end

    # Check a precondition for the next block; if this fails you have
    # something odd in your set of face, and we skip testing things that
    # matter. --daniel 2011-04-10
    it "has at least one face with a summary" do
      Puppet::Face.faces.should be_any do |name|
        Puppet::Face[name, :current].summary
      end
    end

    it "lists all faces which are runnable from the command line" do
      help_face = Puppet::Face[:help, :current]
      # The main purpose of the help face is to provide documentation for
      #  command line users.  It shouldn't show documentation for faces
      #  that can't be run from the command line, so, rather than iterating
      #  over all available faces, we need to iterate over the subcommands
      #  that are available from the command line.
      Puppet::Util::CommandLine.available_subcommands.each do |name|
        next unless help_face.is_face_app?(name)
        next if help_face.exclude_from_docs?(name)
        face = Puppet::Face[name, :current]
        summary = face.summary

        subject.should =~ %r{ #{name} }
        summary and subject.should =~ %r{ #{name} +#{summary}}
      end
    end

    context "face summaries" do
      # we need to set a bunk module path here, because without doing so,
      #  the autoloader will try to use it before it is initialized.
      Puppet[:modulepath] = "/dev/null"

      Puppet::Face.faces.each do |name|
        it "has a summary for #{name}" do
          Puppet::Face[name, :current].should have_a_summary
        end
      end
    end
  end
end
