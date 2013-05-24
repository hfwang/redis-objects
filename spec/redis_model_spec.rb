require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'redis/objects'
require 'redis/model'

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

  it "should initialize with given attributes" do
    p = Player.new(:name => 'foo', :level => 1)
    p.name.should == 'foo'
    p.level.should == 1
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
    @player1 = Player.find(1)
    @player1.name.should == 'Foo'
    @player1.points.should == 2
    @player1.points.class.should == Fixnum
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
    Redis.current.exists(@player2.redis_key).should == true
    @player2.destroy
    Redis.current.exists(@player2.redis_key).should == false
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

  it "should throw RecordNotFound" do
    lambda {
      SimplePlayer.find(2_000_000)
    }.should.raise(::Redis::Model::RecordNotFound)
  end

  it "should run creation and update callbacks" do
    class CallbackPlayer
      @@update_count = 0
      @@create_count = 0

      include Redis::Model
      persistent_attributes(:name => String)

      before_save :before_save_method
      after_create :after_create_method

      def before_save_method
        @@update_count += 1
      end

      def after_create_method
        @@create_count += 1
      end
    end

    player = CallbackPlayer.create(:name => "foo")
    CallbackPlayer.class_eval('@@update_count').should == 1
    CallbackPlayer.class_eval('@@create_count').should == 1
    player.name = 'bar'
    player.save
    CallbackPlayer.class_eval('@@update_count').should == 2
  end

  it "should properly handle dirty tracking" do
    @player2.changed?.should == false

    @player2.name = 'New name'
    @player2.changed?.should == true

    @player2.save
    @player2.changed?.should == false

    @player2.name = 'New name'
    @player2.changed?.should == false
  end

  it "should track new_record-ness" do
    @player2.new_record?.should == false
    Player.find(@player2.id).new_record?.should == false

    p = Player.new(:name => 'foo')
    p.new_record?.should == true
    p.save
    p.new_record?.should == false
  end
end
