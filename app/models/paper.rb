class Paper 
  include MongoMapper::Document
  key :title, String
  key :github_address, String
  key :version, String, :default => "1.0"
  key :state, String
  key :category, String
  key :arxiv_id, String
  key :author_ids, Array
  key :pdf_url, String
  key :pngs_generated, Boolean
  key :authors, Array
  key :submitted_at, DateTime

  # has_many   :authors, :in => :author_ids
  # has_one    :submitting_author
  # belongs_to :reviewer

  has_many :tasks

  after_create :pull_arxiv_details
  after_create :make_pngs
  
  state_machine :initial => :submitted do 
    state :submitted
    state :under_review
    state :accepted
  end
  
  def arxiv_no
    arxiv_id.split("/").last
  end
  
  def add_issue(title, text)
    GITHUB_CONNECTION.create_issue(repo_name, title, text, :labels => review_name)
  end

  def self.id_from_request_uri(uri)
    uri.split("/").last.split("?").first
  end

  def update_issue(repo_name, issue_id, text, labels=nil)
    GITHUB_CONNECTION.update_issue(repo_name, issue_id, text, :labels => labels)
  end
  
  def close_issue(issue_id)
    GITHUB_CONNECTION.close_issue(repo_name, issue_id)
  end

  def repo_name
    github_address.match(/:([^\/]+\/.+?)\.git/)[1]
  end

  def issues
    GITHUB_CONNECTION.list_issues(repo_name)
  end

  def review_name
    "Review ##{version}"
  end

  private

  def pull_arxiv_details
    github_address = ArxivDownloader.perform_async(self.arxiv_id, self.id)
    save
  end
  
  def make_pngs
    PngGenerator.perform_async(self.id, self.pdf_url)
  end
end
