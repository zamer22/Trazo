-- Restaurantes alrededor del Tecnológico de Monterrey (ITESM Campus Monterrey)
-- Centro aproximado: 25.6515, -100.2890
-- Radio: ~1.5 km

WITH nuevos_restaurantes AS (
    INSERT INTO public.restaurantes (id, nombre, descripcion, tipo, latitud, longitud, rating_promedio, total_calificaciones)
    VALUES
        (gen_random_uuid(), 'Starbucks Tec',          'Café junto a la entrada principal del Tec.',          'cafe',           25.6498, -100.2876, 4.4, 152),
        (gen_random_uuid(), 'La Madre Café',          'Café de especialidad y desayunos saludables.',        'cafe',           25.6532, -100.2911, 4.7, 98),
        (gen_random_uuid(), 'Tacos El Charro',        'Tacos al pastor frente al Tec.',                      'tacos',          25.6485, -100.2862, 4.5, 210),
        (gen_random_uuid(), 'Las Costillas de Sancho','Costillas y carnes asadas — clásico estudiantil.',    'restaurante',    25.6541, -100.2868, 4.3, 175),
        (gen_random_uuid(), 'Green & Co',             'Bowls y ensaladas post-corrida.',                     'saludable',      25.6520, -100.2845, 4.6, 87),
        (gen_random_uuid(), 'Bisquets Obregón',       'Desayunos mexicanos y café con leche.',               'cafe',           25.6553, -100.2895, 4.4, 134),
        (gen_random_uuid(), 'Pizza Campus',           'Pizzas individuales y por rebanada.',                 'pizzeria',       25.6500, -100.2920, 4.2, 96),
        (gen_random_uuid(), 'Burger Lab MTY',         'Hamburguesas artesanales con papas trufa.',           'hamburgueseria', 25.6470, -100.2890, 4.5, 142),
        (gen_random_uuid(), 'Panadería La Espiga',    'Pan recién horneado y conchas calientes.',            'panaderia',      25.6560, -100.2855, 4.6, 78),
        (gen_random_uuid(), 'Sushi Roll Tec',         'Sushi y bowls cerca de Garza Sada.',                  'restaurante',    25.6478, -100.2918, 4.1, 112),
        (gen_random_uuid(), 'Heladería La Nueva Era', 'Helados artesanales y nieves.',                       'helados',        25.6529, -100.2882, 4.7, 65),
        (gen_random_uuid(), 'Tacos Don Beto',         'Tacos de trompo y suadero hasta tarde.',              'tacos',          25.6545, -100.2912, 4.4, 188),
        (gen_random_uuid(), 'Wing Stop Garza Sada',   'Alitas y tenders con salsas variadas.',               'restaurante',    25.6505, -100.2858, 4.0, 124),
        (gen_random_uuid(), 'Café Punta del Cielo',   'Café gourmet mexicano frente al Tec.',                'cafe',           25.6512, -100.2902, 4.5, 91)
    RETURNING id, nombre
)
INSERT INTO public.cupones_restaurante (id, restaurante_id, titulo, descripcion, codigo, descuento_porcentaje, visitas_requeridas)
SELECT
    gen_random_uuid(),
    r.id,
    c.titulo,
    c.descripcion,
    c.codigo,
    c.descuento_porcentaje,
    c.visitas_requeridas
FROM nuevos_restaurantes r
JOIN (VALUES
    ('Starbucks Tec',           '15% en bebida fría',           'Recompensa post-corrida en tu Frappuccino favorito.',  'TRAZO15SBX',  15, 1),
    ('La Madre Café',           'Café gratis',                  'Después de 3 visitas, tu siguiente americano va por la casa.', 'TRAZOCAFE3', 100, 3),
    ('Tacos El Charro',         '2x1 en tacos al pastor',       'Repón calorías con un 2x1 al pastor.',                 'TRAZOPASTOR', 50, 2),
    ('Las Costillas de Sancho', '20% en cuenta total',          'Aplica de lunes a jueves.',                            'TRAZOSANCHO', 20, 1),
    ('Green & Co',              '25% en bowl saludable',        'Hidrátate y come limpio después de tu Trazo.',         'TRAZOGREEN',  25, 1),
    ('Bisquets Obregón',        'Café con leche gratis',        'Con desayuno completo.',                               'TRAZOBISQ',  100, 2),
    ('Pizza Campus',            '30% en pizza personal',        'Para corredores universitarios.',                      'TRAZOPIZZA',  30, 1),
    ('Burger Lab MTY',          'Papas trufa gratis',           'Con cualquier hamburguesa.',                           'TRAZOBURGER',100, 1),
    ('Panadería La Espiga',     'Concha gratis',                'Con compra mínima de $50.',                            'TRAZOPAN',   100, 1),
    ('Sushi Roll Tec',          '15% en rolls',                 'De lunes a miércoles.',                                'TRAZOSUSHI',  15, 1),
    ('Heladería La Nueva Era',  '2x1 en bola sencilla',         'Refresca tu post-corrida.',                            'TRAZOHELADO', 50, 1),
    ('Tacos Don Beto',          '5 tacos por $99',              'Promo runner nocturna.',                               'TRAZODONBETO',30, 1),
    ('Wing Stop Garza Sada',    '10 alitas por $149',           'Después de tu trazo largo.',                           'TRAZOWINGS',  25, 2),
    ('Café Punta del Cielo',    'Latte gratis',                 'Tu cuarta visita es por la casa.',                     'TRAZOPUNTA', 100, 4)
) AS c(nombre, titulo, descripcion, codigo, descuento_porcentaje, visitas_requeridas)
ON r.nombre = c.nombre;
