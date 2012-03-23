require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
require 'redis/model'

Redis::Objects.redis = $redis

class Player
  include Redis::Model
  persistent_attributes(:name => String,
                        :level => Integer,
                        :points => Integer,
                        # true => marshal this key
                        :positions => true)
  self.defaults = {:level => 1}
end

describe Redis::Model do
  before do
    @player1 = Player.new({:id => 1})
    @player2 = Player.create({
        :id => 2,
        :name => 'John Doe',
        :points => 1,
        :positions => {}})
  end

  it "should use defaults sanely" do
    @player1.name.should == nil
    @player1.level.should == 1
  end

  it "should find pre-existing data" do
    p = Player.find(2)
    p.id.should == 2
    p.name.should == 'John Doe'
    p.points.should == 1
  end

  it "should save and load fields" do
    @player1.name = "Foo"
    @player1.points = 2
    @player1.positions = {:foo => :bar, :baz => :buz}
    @player1.save
    @player1 = Player.new(:id => 1)
    @player1.name.should == 'Foo'
    @player1.points.should == 2
  end

  it "should support complex marshalling" do
    @player2.positions = {
      :pitcher => true,
      :catcher => false
    }
    @player2.positions[:pitcher].should == true
    @player2.positions[:catcher].should == false

    @player2.save

    player2 = Player.find(2)
    player2.positions[:pitcher].should == true
    player2.positions[:catcher].should == false
  end
end
