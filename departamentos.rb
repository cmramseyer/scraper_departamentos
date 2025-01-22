require 'nokogiri'
require 'open-uri'
require 'pg'
require 'dotenv'
Dotenv.load

TELEGRAM_CHAT_ID = ENV['TELEGRAM_CHAT_ID']
TELEGRAM_TOKEN = ENV['TELEGRAM_TOKEN']

puts TELEGRAM_CHAT_ID

# Configuración de conexión a la base de datos
DB_CONFIG = {
  dbname: ENV['DB_NAME'],
  user: ENV['DB_USER'],
  password: ENV['DB_PASS'],
  host: ENV['DB_HOST'],
  port: ENV['DB_PORT']
}
# URL de la web para scrapear
URL = ENV['URL']
# Método para enviar mensajes a Telegram
def send_telegram_message(message)
  uri = URI("https://api.telegram.org/bot#{TELEGRAM_TOKEN}/sendMessage")
  params = { chat_id: TELEGRAM_CHAT_ID, text: message }
  response = Net::HTTP.post_form(uri, params)
  puts "Dpto nuevo: #{message}" if response.is_a?(Net::HTTPSuccess)
end

def scrape_departamentos
  # Conexión a la base de datos
  puts Time.now.getlocal('-03:00')
  conn = PG.connect(DB_CONFIG)


  # Crear tabla si no existe
  conn.exec <<-SQL
    CREATE TABLE IF NOT EXISTS departamentos (
      id SERIAL PRIMARY KEY,
      anuncio_id TEXT,
      direccion TEXT NOT NULL,
      precio TEXT NOT NULL,
      features TEXT,
      url TEXT,
      fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(direccion, precio)
    );
  SQL

  # Descargar y parsear el HTML
  html = URI.open(URL)
  doc = Nokogiri::HTML(html)

  # Iterar sobre los anuncios
  doc.css('.listing__item').each do |anuncio|
    direccion = anuncio.at_css('.card__address')&.text&.strip
    precio = anuncio.at_css('.card__price')&.text&.strip&.gsub(/\s+/, "")&.gsub("&plus", "+")
    anuncio_id = nil
    url = anuncio.at_css('a.card')['href']
    # anuncio_id = anuncio.at_css('.id')&.text&.strip
    features = anuncio.at_css('.card__main-features')&.text&.strip&.gsub(/\s+/, "")

    # Validar datos


    next if direccion.nil? || precio.nil? || features.nil?

    # Comprobar si el departamento ya existe
    existing = conn.exec_params(
      "SELECT 1 FROM departamentos WHERE direccion = $1 AND precio = $2",
      [direccion, precio]
    )
    next unless existing.ntuples.zero?

    # Insertar el departamento en la tabla
    conn.exec_params(
      "INSERT INTO departamentos (anuncio_id, direccion, precio, features, url) VALUES ($1, $2, $3, $4, $5)",
      [anuncio_id, direccion, precio, features, url]
    )

    mensaje = "#{direccion}, #{precio}, #{features}\n #{ENV['PREFIX_ARGENPROP']}#{url}"
    send_telegram_message(mensaje)
    sleep(10)
  end

  # Cerrar conexión
  conn.close
end

# Ejecutar el scraper
scrape_departamentos


