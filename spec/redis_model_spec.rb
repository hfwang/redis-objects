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

class SimplePlayer
  include Redis::Model
  persistent_attributes(:name => String)
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

  after do
    Player.id_generator.clear
    SimplePlayer.id_generator.clear
  end

  it "should use defaults sanely" do
    @player1.name.should == nil
    @player1.level.should == 1
  end

  it "should respect persistent attributes typing" do
    p = Player.find(2)
    p.name.class.should == String
    p.points.is_a?(Fixnum).should == true
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

  it "should delete the key on destroy" do
    $redis.exists(@player2.redis_key).should == true
    @player2.destroy
    $redis.exists(@player2.redis_key).should == false
  end

  it "should autogenerate IDs" do
    players = []
    ['A', 'B', 'C'].each do |name|
      players << SimplePlayer.create(:name => name)
    end
    players.size.should == 3
    players[0].id.should == 1
    players[1].id.should == 2
    players[2].id.should == 3
    SimplePlayer.last_generated_id.should == 3
  end
end
