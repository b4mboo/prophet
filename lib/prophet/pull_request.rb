class PullRequest

  attr_accessor :id,
                :content,
                :comment,
                :head_sha,
                :target_head_sha,
                :from_fork

  def initialize(content)
    @content = content
    @id = content.number
    @head_sha = content.head.sha
    @from_fork = content.head.repo.fork
  end

end
