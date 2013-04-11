class PullRequest

  attr_accessor :id,
                :content,
                :comment,
                :head_sha,
                :target_head_sha

  def initialize(content)
    @content = content
    @id = content.number
    @head_sha = content.head.sha
  end

end
