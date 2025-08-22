import { supabase } from '../lib/supabase'
import { faker } from '@faker-js/faker/locale/pt_BR'
import { getOrCreateChatRoom } from './chat'

/**
 * Generates sample news and product data.
 */
export async function generateSampleData() {
  try {
    const newsCategories = ['geral', 'política', 'economia', 'esportes', 'cultura', 'saúde', 'segurança', 'trânsito']
    const locations = ['Centro', 'São Mateus', 'Santa Helena', 'São Pedro', 'Benfica', 'Santa Luzia', 'Bairu', 'Cascatinha']
    
    const sampleNews = Array.from({ length: 10 }, () => ({
      title: faker.lorem.sentence({ min: 5, max: 10 }),
      content: faker.lorem.paragraphs(2, '\n\n'),
      category: faker.helpers.arrayElement(newsCategories),
      location: `${faker.helpers.arrayElement(locations)}, Juiz de Fora - MG`
    }))

    const productCategories = ['eletrônicos', 'móveis', 'roupas', 'veículos', 'casa', 'esportes', 'livros', 'outros']
    const conditions = ['novo', 'seminovo', 'usado'] as const
    
    const sampleProducts = Array.from({ length: 15 }, () => ({
      title: faker.commerce.productName(),
      description: faker.commerce.productDescription(),
      price: parseFloat(faker.commerce.price({ min: 10, max: 5000, dec: 2 })),
      condition: faker.helpers.arrayElement(conditions),
      category: faker.helpers.arrayElement(productCategories),
      location: `${faker.helpers.arrayElement(locations)}, Juiz de Fora, MG`
    }))

    return { sampleNews, sampleProducts }
  } catch (error) {
    console.error('Error generating sample data:', error)
    return { sampleNews: [], sampleProducts: [] }
  }
}

/**
 * Seeds the database with realistic sample data, including a sample conversation.
 * @param currentUserId The ID of the currently logged-in user.
 */
export async function seedDatabase(currentUserId: string) {
  try {
    // Find the test seller created by a previous migration
    const { data: testSellerData, error: sellerError } = await supabase
      .from('profiles')
      .select('id')
      .eq('username', 'vendedor_teste')
      .single();

    if (sellerError || !testSellerData) {
      console.error('Test seller not found. Cannot create sample conversation.', sellerError);
      alert('Vendedor de teste não encontrado. Apenas dados para seu usuário serão criados. Rode a migração anterior para criar o vendedor de teste.');
      // Fallback to creating data only for the current user
      const { sampleNews, sampleProducts } = await generateSampleData();
      const newsWithUserId = sampleNews.map(news => ({ ...news, user_id: currentUserId }));
      const productsWithUserId = sampleProducts.map(product => ({ ...product, user_id: currentUserId }));
      await supabase.from('news_posts').insert(newsWithUserId);
      await supabase.from('marketplace_products').insert(productsWithUserId);
      return true;
    }

    const testSellerId = testSellerData.id;

    console.log('Generating sample data for current user and test seller...');
    const { sampleNews, sampleProducts } = await generateSampleData();

    // Assign most data to the test seller and some to the current user
    const newsWithUserIds = sampleNews.map((news, index) => ({
      ...news,
      user_id: index < 3 ? currentUserId : testSellerId
    }));
    const productsWithUserIds = sampleProducts.map((product, index) => ({
      ...product,
      user_id: index < 4 ? currentUserId : testSellerId
    }));

    await supabase.from('news_posts').insert(newsWithUserIds);
    await supabase.from('marketplace_products').insert(productsWithUserIds);
    console.log('Sample posts and products seeded successfully!');

    // Create a sample conversation
    console.log('Creating sample conversation...');
    const roomId = await getOrCreateChatRoom(currentUserId, testSellerId);

    if (roomId) {
      const sampleMessages = [
        { room_id: roomId, user_id: testSellerId, content: 'Olá! Vi que você se interessou pelo meu produto. Posso ajudar em algo?' },
        { room_id: roomId, user_id: currentUserId, content: 'Oi! Sim, gostaria de saber mais detalhes sobre o estado de conservação.' },
        { room_id: roomId, user_id: testSellerId, content: 'Claro! Ele está em ótimo estado, quase sem marcas de uso. Quer mais fotos?' },
      ];

      const { error: messagesError } = await supabase.from('chat_messages').insert(sampleMessages);
      if (messagesError) {
        console.error('Error seeding sample messages:', messagesError);
      } else {
        console.log('Sample conversation created successfully!');
      }
    } else {
      console.error('Could not create or find chat room for sample conversation.');
    }

    return true;
  } catch (error) {
    console.error('Error seeding database:', error);
    return false;
  }
}
