import { supabase } from '../lib/supabase'
import { faker } from '@faker-js/faker'

export async function generateSampleData() {
  try {
    // Generate sample news posts
    const newsCategories = ['geral', 'política', 'economia', 'esportes', 'cultura', 'saúde', 'segurança', 'trânsito']
    const locations = ['Centro', 'São Mateus', 'Santa Helena', 'São Pedro', 'Benfica', 'Santa Luzia', 'Botanágua', 'Cascatinha']
    
    const sampleNews = Array.from({ length: 10 }, () => ({
      title: faker.lorem.sentence({ min: 5, max: 10 }),
      content: faker.lorem.paragraphs(2, '\n\n'),
      category: faker.helpers.arrayElement(newsCategories),
      location: `${faker.helpers.arrayElement(locations)}, Juiz de Fora - MG`
    }))

    // Generate sample marketplace products
    const productCategories = ['eletrônicos', 'móveis', 'roupas', 'veículos', 'casa', 'esportes', 'livros', 'outros']
    const conditions = ['novo', 'seminovo', 'usado'] as const
    
    const sampleProducts = Array.from({ length: 15 }, () => ({
      title: faker.commerce.productName(),
      description: faker.commerce.productDescription(),
      price: parseFloat(faker.commerce.price({ min: 10, max: 5000, dec: 2 })),
      condition: faker.helpers.arrayElement(conditions),
      category: faker.helpers.arrayElement(productCategories),
      location: `${faker.helpers.arrayElement(locations)}, Juiz de Fora - MG`
    }))

    return { sampleNews, sampleProducts }
  } catch (error) {
    console.error('Error generating sample data:', error)
    return { sampleNews: [], sampleProducts: [] }
  }
}

export async function seedDatabase(userId: string) {
  try {
    const { sampleNews, sampleProducts } = await generateSampleData()

    // Insert sample news
    const newsWithUserId = sampleNews.map(news => ({
      ...news,
      user_id: userId
    }))

    const { error: newsError } = await supabase
      .from('news_posts')
      .insert(newsWithUserId)

    if (newsError) throw newsError

    // Insert sample products
    const productsWithUserId = sampleProducts.map(product => ({
      ...product,
      user_id: userId
    }))

    const { error: productsError } = await supabase
      .from('marketplace_products')
      .insert(productsWithUserId)

    if (productsError) throw productsError

    console.log('Sample data inserted successfully!')
    return true
  } catch (error) {
    console.error('Error seeding database:', error)
    return false
  }
}
