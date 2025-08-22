import React, { useState, useEffect, useCallback } from 'react'
import { RefreshCw, TrendingUp } from 'lucide-react'
import { motion } from 'framer-motion'
import { FeedPost } from './FeedPost'
import { LoadingSpinner } from '../Common/LoadingSpinner'
import { EmptyState } from '../Common/EmptyState'
import { supabase } from '../../lib/supabase'
import { useAuth } from '../../contexts/AuthContext'

export function FeedScreen() {
  const [posts, setPosts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [userLikes, setUserLikes] = useState<Set<string>>(new Set())
  const { user } = useAuth()

  const fetchPostsAndLikes = useCallback(async () => {
    if (!user) {
      setLoading(false)
      return
    }

    try {
      // Fetch posts
      const { data: postData, error: postError } = await supabase
        .from('news_posts')
        .select(`
          id,
          title,
          content,
          category,
          location,
          likes_count,
          comments_count,
          created_at,
          profiles!news_posts_user_id_fkey (
            username,
            full_name,
            avatar_url
          )
        `)
        .order('created_at', { ascending: false })
        .limit(20)

      if (postError) throw postError
      setPosts(postData || [])

      // Fetch user likes for posts
      const { data: likeData, error: likeError } = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', user.id)
        .not('post_id', 'is', null) // FIX: Correctly check for non-null post_id

      if (likeError) throw likeError
      const likedPostIds = new Set(likeData.map(like => like.post_id).filter(Boolean) as string[])
      setUserLikes(likedPostIds)

    } catch (error) {
      console.error('Error fetching posts and likes:', error)
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }, [user])

  useEffect(() => {
    fetchPostsAndLikes()
  }, [fetchPostsAndLikes])

  const handleRefresh = async () => {
    setRefreshing(true)
    await fetchPostsAndLikes()
  }

  const handleLike = async (postId: string) => {
    if (!user) return

    const isLiked = userLikes.has(postId)
    
    // Optimistic UI update
    const newLikes = new Set(userLikes)
    if (isLiked) {
      newLikes.delete(postId)
    } else {
      newLikes.add(postId)
    }
    setUserLikes(newLikes)

    setPosts(prev => prev.map(post => 
      post.id === postId 
        ? { ...post, likes_count: isLiked ? Math.max(0, post.likes_count - 1) : post.likes_count + 1 }
        : post
    ))

    try {
      if (isLiked) {
        // Unlike
        await supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id)
      } else {
        // Like
        await supabase
          .from('post_likes')
          .insert([{ post_id: postId, user_id: user.id }])
      }
    } catch (error) {
      console.error('Error toggling like, reverting UI:', error)
      // Revert UI on error
      setUserLikes(userLikes)
      setPosts(posts)
    }
  }

  const handleComment = (postId: string) => {
    // TODO: Implement comment modal
    console.log('Comment on post:', postId)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <LoadingSpinner size="lg" text="Carregando notícias..." />
      </div>
    )
  }

  return (
    <div className="pb-20 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="sticky top-0 bg-white border-b border-gray-200 p-4 flex items-center justify-between z-10 shadow-sm">
        <div className="flex items-center space-x-3">
          <h1 className="text-xl font-bold text-gray-900">📰 JF Notícias</h1>
          <div className="flex items-center space-x-1 text-green-600">
            <TrendingUp size={16} />
            <span className="text-sm font-medium">Trending</span>
          </div>
        </div>
        
        <motion.button
          onClick={handleRefresh}
          className={`p-2 rounded-full hover:bg-gray-100 transition-colors ${refreshing ? 'animate-spin' : ''}`}
          whilePressed={{ scale: 0.95 }}
          disabled={refreshing}
        >
          <RefreshCw size={20} className="text-gray-600" />
        </motion.button>
      </div>

      {/* Content */}
      <div className="p-4">
        {posts.length === 0 ? (
          <EmptyState
            icon="📰"
            title="Nenhuma notícia ainda"
            description="Seja o primeiro a compartilhar uma notícia sobre Juiz de Fora!"
            action={{
              label: "Criar primeira notícia",
              onClick: () => console.log('Create first post')
            }}
          />
        ) : (
          <div className="space-y-4">
            {posts.map((post, index) => (
              <motion.div
                key={post.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
              >
                <FeedPost
                  post={post}
                  isLiked={userLikes.has(post.id)}
                  onLike={handleLike}
                  onComment={handleComment}
                />
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
