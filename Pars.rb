require 'nokogiri'
require 'curb'
require 'csv'

@url = ARGV[0].to_s
@file = ARGV[1].to_s

puts "----------Создание файла----------------------------"
CSV.open(@file, "wb") do |csv|
  csv << ["Name".ljust(100), "Price".ljust(14), "Image"]
end

puts "----------Сбор ссылок на страницы каталога----------"
links=[]
links.push(@url)
i = 2
num = 11
while i < num do
  main_link = @url + "?p=#{i}"
  links.push(main_link)
  i += 1
end

puts "----------Сбор ссылок на товары---------------------"
pages = []
number = 0
threads = []
links.each do |link|
  threads << Thread.new(link) do |url|
    catalog = Curl.get(url)
    main_page = Nokogiri::HTML(catalog&.body)
    main_page.xpath('//*[@id="product_list"]/li/div/div/div[1]/a/@href').each do |row|
      pages.push(row.to_s)
    end
  end
end
threads.each do |t|
  t.join
  number += 1
  puts (number * 100 / links.length).to_s + "% ссылок на товары собрано"
end

puts "----------Создание потоков для парсинга--------------"
full_info = []
threads = []
number = 0
pages.each do |pag|
  threads << Thread.new(pag) do |url|
    page = Curl.get(url)
    doc = Nokogiri::HTML(page&.body)
    names = []
    prices = []
    if (name = doc.xpath('//*[@id="center_column"]/div/div/div[2]/div[2]/h1/text()').to_s).length < 3 then
      name = doc.xpath('//*[@id="center_column"]/div/div/div[2]/div[1]/h1/text()').to_s
    end
    name = name.gsub("\"", "'")
    doc.xpath('//*[@id="attributes"]/fieldset/div/ul/li/label/span[1]/text()').each do |weight|
      names.push(name + " - " + weight.to_s)
    end
    doc.xpath('//*[@id="attributes"]/fieldset/div/ul/li/label/span[2]/text()').each do |price|
      prices.push(price.to_s.to_f.to_s)
    end
    image = doc.xpath('//*[@id="bigpic"]/@src')
    i = 0
    while i < names.length do
      full_info.push([names[i].ljust(100),prices[i].ljust(14), image])
      i += 1
    end
  end
  number += 1
  if number%30 == 0 then
    puts (number * 100 / pages.length).to_s + "% потоков для сбора информации о товарах создано"
  end
end
puts "----------Сбор информации о товарах------------------"
number = 0
threads.each do |t|
  t.join
  number += 1
  if number%5 == 0 then
    puts (number * 100 / pages.length).to_s + "% информации о товарах собрано"
  end
end

puts "-------Добавление информации о товарах в файл---------"
full_info.each do |line|
  CSV.open(@file, "a+") do |csv|
    csv << line
  end
end
puts "Готово"
