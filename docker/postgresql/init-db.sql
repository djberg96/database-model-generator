-- PostgreSQL test database initialization script
-- Create sample tables for testing the model generator

-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    role VARCHAR(20) DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_status CHECK (status IN ('active', 'inactive', 'suspended', 'deleted')),
    CONSTRAINT check_role CHECK (role IN ('user', 'admin', 'moderator'))
);

-- Create posts table
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(20) DEFAULT 'draft',
    priority VARCHAR(10) DEFAULT 'medium',
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT check_post_status CHECK (status IN ('draft', 'published', 'archived')),
    CONSTRAINT check_priority CHECK (priority IN ('low', 'medium', 'high', 'urgent'))
);

-- Create comments table (with polymorphic association)
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    commentable_id INTEGER NOT NULL,
    commentable_type VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT check_comment_status CHECK (status IN ('active', 'hidden', 'deleted'))
);

-- Create tags table
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(60) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create post_tags (join table)
CREATE TABLE post_tags (
    post_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (post_id, tag_id),
    CONSTRAINT fk_post_tags_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    CONSTRAINT fk_post_tags_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_created_at ON posts(created_at);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_commentable ON comments(commentable_id, commentable_type);

-- Create a full-text search index
CREATE INDEX idx_posts_title_content_text ON posts USING GIN (to_tsvector('english', title || ' ' || COALESCE(content, '')));

-- Insert sample data
INSERT INTO users (username, email, first_name, last_name, status, role) VALUES
    ('john_doe', 'john@example.com', 'John', 'Doe', 'active', 'admin'),
    ('jane_smith', 'jane@example.com', 'Jane', 'Smith', 'active', 'user'),
    ('bob_jones', 'bob@example.com', 'Bob', 'Jones', 'inactive', 'moderator');

INSERT INTO posts (user_id, title, content, status, priority) VALUES
    (1, 'First Post', 'This is the content of the first post', 'published', 'high'),
    (1, 'Second Post', 'This is the content of the second post', 'draft', 'medium'),
    (2, 'Jane''s Post', 'Jane writes about something interesting', 'published', 'low');

INSERT INTO tags (name, slug) VALUES
    ('Technology', 'technology'),
    ('Ruby', 'ruby'),
    ('PostgreSQL', 'postgresql');

INSERT INTO post_tags (post_id, tag_id) VALUES
    (1, 1),
    (1, 2),
    (3, 1),
    (3, 3);

INSERT INTO comments (user_id, commentable_id, commentable_type, content) VALUES
    (2, 1, 'Post', 'Great post!'),
    (3, 1, 'Post', 'Thanks for sharing');
