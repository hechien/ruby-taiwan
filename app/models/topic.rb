# coding: utf-8
class Topic
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::BaseModel
  include Mongoid::SoftDelete
  include Mongoid::CounterCache
  include Redis::Objects
  include Sunspot::Mongoid

  field :title
  field :body
  field :last_reply_id, :type => Integer
  field :replied_at , :type => DateTime
  field :source
  field :message_id
  field :replies_count, :type => Integer, :default => 0
  # 回复过的人的 ids 列表
  field :follower_ids, :type => Array, :default => []
  field :suggested_at, :type => DateTime
  field :likes_count, :type => Integer, :default => 0

  belongs_to :user, :inverse_of => :topics
  counter_cache :name => :user, :inverse_of => :topics
  belongs_to :node
  counter_cache :name => :node, :inverse_of => :topics
  belongs_to :last_reply_user, :class_name => 'User'
  has_many :replies, :dependent => :destroy

  attr_protected :user_id
  validates_presence_of :user_id, :title, :body, :node_id
  
  index :node_id
  index :user_id
  index :replied_at
  index :suggested_at

  counter :hits, :default => 0

  searchable do
    text :title, :stored => true
    text :body, :stored => true
    text :replies, :stored => true do
      replies.map { |reply| reply.body }
    end
    integer :node_id, :user_id
    boolean :deleted_at
    time :replied_at
  end
  
  # scopes
  scope :last_actived, desc("replied_at").desc("created_at")
  # 推荐的话题
  scope :suggest, where(:suggested_at.ne => nil).desc(:suggested_at)
  before_save :set_replied_at
  def set_replied_at
    self.replied_at = Time.now
  end

  def node_name
    node.try(:name) || ""
  end

  def push_follower(user_id)
    self.follower_ids << user_id if !self.follower_ids.include?(user_id)
  end

  def pull_follower(user_id)
    self.follower_ids.delete(user_id)
  end
  
  def update_last_reply(reply)
    self.replied_at = Time.now
    self.last_reply_id = reply.id
    self.last_reply_user_id = reply.user_id
    self.push_follower(reply.user_id)
    self.save
  end

  def self.find_by_message_id(message_id)
    where(:message_id => message_id).first
  end
end
