#!/usr/bin/env ruby
# encoding: UTF-8
# coding: UTF-8

# JotForm data download utility
# RU: Утилита скачивания JotForm данных
# 2021 (c) robux@mail.ru

#Command line format:
#RU: Формат командной строки:
#
#  ruby.exe DnlFiles.rb <api_key> [<form_id>] [<base_dir>] [<start_time>] [<sub_id>]
#
#    <api_key> - api-key from "Settings/API" in web-cabinet
#    <form_id> - not mandatory parameter, form's ID or word "ALL"
#    <base_dir> - not mandatory parameter, for set saving directory (can be "default")
#    <start_time> - not mandatory parameter, will load files from this date/time
#    <sub_id> - not mandatory parameter, submission id
#
#  Examples:
#  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c 232525643543748
#  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all
#  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all "/home/user/MyData"
#  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all "default" "2021-07-30"
#  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c all "F:" "2020.12.31 23:59:55"
#  ruby.exe DnlFiles.rb f84e264df59951530a761763798b1c 324323863549362 "default" "2021-07-30" 4546889675119265290


# Net::HTTP necessary for downloads
require 'net/http'
# FileUtils module is necessary for recursive folder creation
require 'fileutils'
require 'openssl'
require 'time'
# Try to include PDF library
$pdf_is_active = false
begin
  require 'prawn'
  $pdf_is_active = true
rescue Exception
  puts("Prawn error. Install packet 'prawn' by command 'gem install prawn' to generate PDF")
end
# Include JotForm Ruby module
require_relative 'JotForm2'

#Directory for downloading
#RU: Каталог для сохранения
#$base_dir = './FormsData'
#$base_dir = 'C:\MyData\JotForm'
$base_dir = Dir.home   #Home directory /home/user or C:/Users/user
$start_time_file = File.join(Dir.pwd, 'start_time.txt')   #File for remembering last created report time

#Skip existed pdf
#RU: Пропускать существующие PDF
$skip_existed_pdf = true

#Start download from DATE and TIME
#RU: Скачивать начиная с указанной даты и времени
#$start_from_time=nil
$start_from_time='2010-01-01 00:00:00'
#$start_from_time='2021-07-20 00:00:00'

$processing = true
$was_errors = false
$saving_fields = false
$manual_setted_start_time = false
$last_created_time = 0
#Print to console immediately
$stdout.sync = true

#Delete double spaces from file paths and names
#RU: Удалять двойные пробелы из путей и имён файлов
DeleteDoubleSpaces = false
#Portion of downloading a list of form
#RU: Порция скачивания списка форм
FormListPortion = 100
#Portion of downloading a list of submission
#RU: Порция скачивания списка отчетов
SubListPortion = 70

#Break on Ctrl+C
trap('SIGINT') do
  if $processing
    puts("\nCtrl+C pressed! Wait a minute please..")
    $processing = false
  elsif not $saving_fields
    puts("\nCtrl+C pressed again! Forced exit!!!")
    Kernel.exit!
  end
end

#Command line parameters processing
#RU: Обработка параметров командной строки
api_key,form_id,submis_id=nil
api_key = ARGV[0].strip if ARGV[0]
form_id = ARGV[1].strip if ARGV[1]
submis_id=ARGV[4].strip if ARGV[4]
form_id = 'all' if (not form_id) or (form_id=='*')
if ARGV[2]
  adir = ARGV[2].strip
  $base_dir = adir if adir and (adir.size>0) and (adir.upcase != 'DEFAULT')
end
if ARGV[3]
  atime = ARGV[3].strip
  if atime.size>=10
    atime = Time.parse(atime)  #Time.strptime(atime, '%Y-%d-%m')
    $start_from_time = atime.strftime('%Y-%m-%d %H:%M:%S')
    $manual_setted_start_time = true
  end
end

if not api_key
  Kernel.abort('Useage: ruby.exe DnlFiles.rb <api_key> [<form_id>] [<base_dir>] [<start_time>] [<sub_id>]')
end

puts('Parameters: api_key='+api_key.to_s+'  form_id='+form_id.to_s+ \
  "\nstart_time="+$start_from_time.to_s+'  base_dir='+$base_dir.to_s)
puts('submission_id='+submis_id.to_s) if submis_id

$uri_parser = URI::Parser.new

#Clear file name from bad symbols
#RU: Почистить имя файла от корявых символов
def clear_file_name(res)
  res.gsub!('"', '`')
  res.gsub!("'", '`')
  res.gsub!('?', '$')
  res.gsub!('*', '#')
  res.gsub!(':', ';')
  res.gsub!('>', '-')
  res.gsub!('<', '-')
  res.gsub!('/', '_')
  res.gsub!("\\", '_')
  res.gsub!('|', '_')
  res = res.gsub(/[\r\n\t]/, ' ')
  res = res.squeeze(' ') if DeleteDoubleSpaces
  res.strip!
  res
end

def get_base_dir(form_id)
  res = File.join($base_dir, 'JotForm', form_id)
end

#Get full saving directory
#RU: Получить полный каталог для сохранения
def get_save_dir(form_id, sub_id)
  res = File.join(get_base_dir(clear_file_name(form_id.to_s)), clear_file_name(sub_id.to_s))
end

def fix_url(url)
  res = url.gsub(/[\[\]]/) { '%%%s' % $&.ord.to_s(16) }
end

#Get HTTP/HTTPS response object
#RU: Взять объект ответа HTTP/HTTPS
def get_http_response(url, limit = 10)
  res = nil
  raise(ArgumentError, 'HTTP redirect too deep ('+limit.to_s+')') if limit<=0
  url = $uri_parser.escape(url)  #unless url.ascii_only?
  uri = URI.parse(fix_url(url))
  options_mask = OpenSSL::SSL::OP_NO_SSLv2 + OpenSSL::SSL::OP_NO_SSLv3 +
    OpenSSL::SSL::OP_NO_COMPRESSION
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Get.new(uri.request_uri)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    #http.options = options_mask
    #http.use_ssl = true
    #http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #TLSv1_2, TLSv1_1, TLSv1, SSLv2, SSLv23, SSLv3
    http.ssl_version = :SSLv23
  end
  response = http.request(req)
  #response = Net::HTTP.start(url.host, url.port, use_ssl: true) { |http| http.request(req) }
  #ssl_context = http.instance_variable_get(:@ssl_context)
  #ssl_context.options == options_mask # => true
  case response
    when Net::HTTPSuccess
      res = response
    when Net::HTTPRedirection
      new_link = response['location']
      new_link = $uri_parser.unescape(new_link)
      puts('Redirect: '+new_link)
      res = get_http_response(new_link, limit - 1) if $processing
    else
      res = response.error!
      #$was_errors = true
  end
  res
end

#Save submission data to TXT or PDF file
#RU: Сохранить данные заполненной формы в TXT или PDF файл
def save_submission(jotform, sub_id, form_id, sub, form_title)
  #sub_id ||= sub['id']
  #form_id ||= sub['form_id']
  sub_folder = nil
  file_url_list = nil
  pdf_saved = nil

  created_at = sub['created_at']

  #Detect main record parameters
  #RU: Найти основные параметры записи
  sub_capt, sub_equip, sub_brend, sub_region, sub_city, sub_sap, sub_vizit = nil
  user_answers = sub['answers']
  user_answers.each do |n,answer|
    answ_text = answer['text'].to_s.strip
    answ_answ = answer['answer']
    answ_type = answer['type'].to_s
    if answ_type != 'control_button'
      answ_text = answer['text'].to_s.strip
      answ_answ = answer['answer']
      if (answ_type == 'control_fileupload')
        if answ_answ.is_a?(Array)
          answ_answ.each do |fn|
            file_url_list ||= []
            file_url_list << fn.to_s
          end
        elsif answ_answ.is_a?(String) and (answ_answ.size>0)
          file_url_list ||= []
          file_url_list << answ_answ
        else
          puts('!!!!Strange file list: '+answ_answ.inspect)
        end
      else
        answ_answ_s = answ_answ.to_s
        if (answ_text != 'Question1') \
        or (answ_answ_s != '')
          if answ_text=='Question2'
            sub_equip = answ_answ_s
          elsif answ_text=='Question3'
            sub_brend = answ_answ_s
          elsif answ_text=='Question4'
            sub_region = answ_answ_s
          elsif answ_text=='Question5'
            sub_city = answ_answ_s
          elsif answ_text=='Question6'
            sub_sap = answ_answ_s
          elsif (answ_text=='Some date') and answ_answ.is_a?(Hash)
            sub_vizit = answ_answ['year']+'.'+answ_answ['month']+'.'+answ_answ['day']
            answ_answ_s = sub_vizit
          end
        end
      end
    end
  end

  #p [sub_equip, sub_brend, sub_region, sub_city, sub_sap, sub_vizit]

  #Compose folder by main parameters
  #RU: Составить путь из основных параметров
  #sub_folder = ''  #sub_id
  #sub_folder += sub_equip if sub_equip
  #sub_folder += '_'+sub_brend if sub_brend
  #sub_folder += '_'+sub_region if sub_region
  #sub_folder += '_'+sub_city if sub_city
  #sub_folder += '_'+sub_sap if sub_sap
  #sub_folder += '_'+sub_vizit if sub_vizit
  sub_folder = sub_id

  form_folder = form_id.to_s
  form_folder += '_'+form_title if form_title
  sub_folder = get_save_dir(form_folder, sub_folder)

  #Create folder if it doesn't exist
  dir_exists = Dir.exists?(sub_folder)
  if not dir_exists
    begin
      #FileUtils.mkdir_p(sub_folder)
      FileUtils.mkpath(sub_folder)
      dir_exists = Dir.exists?(sub_folder)
    rescue Exception => e
      puts('Exception: ' + e.message)
      dir_exists = nil
    end
    if not dir_exists
      puts('Cannot to create folder: ['+sub_folder+']')
      sub_folder = nil
      $was_errors = true
    end
  end

  if dir_exists and sub_folder
    sub_fn = File.join(sub_folder, 'fields')

    sub_fn_txt = sub_fn+'.txt'
    sub_fn_pdf = sub_fn+'.pdf'
    check_file = sub_fn_pdf
    check_file = sub_fn_txt if not $pdf_is_active
    if $skip_existed_pdf and File.exist?(check_file)
      puts('['+check_file+'] exist, skipped')
    else
      puts('download path: '+sub_folder)
      #sub = jotform.getSubmission(sub_id)
      pdf = nil
      #Sub fields: ip, created_at, updated_at, status, new,
      # answers (text, type, answer, prettyFormat), limit-left (the number of daily api calls you can make)
      user_ip = sub['ip']

      #Create PDF and TXT files
      $saving_fields = true
      File.open(sub_fn_txt, 'w') do |file|
        if $pdf_is_active
          pdf = Prawn::Document.new(:page_size => 'A4')
          pdf.font('DroidSans.ttf', :size => 12)
        end
        file.puts('User IP: '+user_ip)
        file.puts('Created: '+created_at)
        if user_answers
          user_answers.each do |n,answer|
            its_caption = false
            answ_type = answer['type'].to_s
            if answ_type != 'control_button'
              answ_text = answer['text'].to_s.strip
              answ_answ = answer['answer']
              if (answ_type == 'control_head') and (not sub_capt)
                its_caption = true
                sub_capt = answ_text
              end
              if (answ_type == 'control_fileupload') and answ_answ.is_a?(Array)
                answ_text = answ_text[0..73].strip+'..' if answ_text.size>=76
                file.puts(n.to_s+'. '+answ_text+':')
                if pdf
                  pdf.font('DroidSans-Bold.ttf', :size => 12) #, :style => :bold)
                  pdf.text(answ_text+':')
                  pdf.font('DroidSans.ttf', :size => 10)
                end
                answ_answ.each do |fn|
                  file.puts('  File: '+fn.to_s)
                  pdf.text((Prawn::Text::NBSP * 2) + fn.to_s) if pdf
                end
                pdf.font('DroidSans.ttf', :size => 12) if pdf
              else
                answ_answ_s = answ_answ.to_s
                if (answ_text != 'Some exclude question') \
                or (answ_answ_s != '')
                  if (answ_text=='Some date') and sub_vizit
                    answ_answ_s = sub_vizit
                  end
                  answ_text = answ_text[0..73].strip+'..' if answ_text.size>=76
                  file.puts(n.to_s+'. '+answ_text+': '+answ_answ_s)
                  if pdf
                    if its_caption
                      pdf.font('DroidSans-Bold.ttf', :size => 16) #, :style => :bold)
                      pdf.text(answ_text, :color => '0000AA')
                    else
                      pdf.font('DroidSans-Bold.ttf', :size => 11) #, :style => :bold)
                      pdf.text(answ_text+': ')
                    end
                    pdf.font('DroidSans.ttf', :size => 12)
                    pdf.text(answ_answ_s) if answ_answ_s
                    pdf.move_down(10) if its_caption
                  end
                end
              end
            end
          end
        end
      end
      if pdf
        pdf.move_down(20)
        pdf.font('DroidSans.ttf', :size => 9)
        pdf.text('IP пользователя: '+user_ip+'.'+(Prawn::Text::NBSP * 2)+'Отчёт отправлен: '+created_at)
        pdf.render_file(sub_fn_pdf)
        puts('PDF/TXT saved.')
        pdf_saved = true
      else
        puts('TXT saved only.')
      end
      $saving_fields = false
    end
  end
  [sub_folder, file_url_list, pdf_saved]
end

#Download all uploaded form files
#RU: Скачивает все загруженные файлы формы
def download_form_files(jotform, api_key, form_id, form_title, submis_id=nil)
  dnl_subs_count = 0
  dnl_files_count = 0
  form_title = form_title.to_s.strip if form_title
  limit = SubListPortion
  offset = 0

  filter = nil
  if $start_from_time
    filter='{"created_at:gt":"'+$start_from_time+'"}'
  end
  orderby = 'created_at ASC'

  continue_dnl = true
  while $processing and continue_dnl
    if submis_id
      sub_info = jotform.getSubmission(submis_id)
      subs_list = [sub_info]
    else
      begin
        subs_list = jotform.getFormSubmissions(form_id, limit, filter, orderby, offset)
      rescue Exception => e
        puts('Error on getFormSubmissions() ' + e.message)
        subs_list = nil
        $was_errors = true
        $processing = false
      end
    end
    if subs_list and $processing
      if subs_list.size+offset>0
        puts('~~~Submission list loaded: '+(subs_list.size+offset).to_s+'..')
      end
      #puts('*** SUBS list: '+subs_list.size.to_s)
      continue_dnl = (subs_list.size==limit)
      subs_list.each do |sub|
        sub_id = sub['id']
        created_at = sub['created_at']
        updated_at = sub['updated_at']
        print('--Submission ['+created_at.to_s+'] '+sub_id.to_s+'.. ')
        sub_folder, file_url_list, pdf_saved = save_submission(jotform, sub_id, form_id, sub, form_title)
        dnl_subs_count += 1 if pdf_saved
        if (sub_folder and file_url_list and (file_url_list.size>0))
          file_url_list.each do |file_url|
            begin
            #if true
              url = $uri_parser.escape(file_url)
              uri = URI.parse(fix_url(url))

              file_name = File.basename(uri.path)
              file_name = $uri_parser.unescape(file_name)

              full_file_name = File.join(sub_folder, clear_file_name(file_name))
              print('File: '+full_file_name+'.. ')
              if File.exist?(full_file_name)
                puts('exist, skipped')
              else
                #Correct url
                url = 'https://eu.'+file_url[12..-1]+'?api_key='+api_key
                begin
                  puts('Downloading: '+url+'.. ')
                  http_response = get_http_response(url)
                  if http_response and http_response.body
                    File.open(full_file_name, 'wb') do |file|
                      file.write(http_response.body)
                      puts('Saved.')
                      # Increment the successful downloads for stats
                      dnl_files_count += 1
                    end
                  else
                    puts('Failed!')
                    $was_errors = true
                  end
                rescue Exception => e
                  puts('Error while downloading ' + file_name + ': ' + e.message)
                  $was_errors = true
                end
              end
            rescue Exception => e
              puts('Error while processing ' + file_url + ': ' + e.message)
              $was_errors = true
            end
            break if not $processing
          end
          break if not $processing
        end
        if created_at and (created_at.size>0) and (not $was_errors) and $processing
          created_at_sec = Time.parse(created_at).to_i
          $last_created_time = created_at_sec if created_at_sec>$last_created_time
        end
      end
    else
      continue_dnl = false
    end
    offset += limit
  end
  #Get list of files from JotFormAPI
  #file_list = jotform.getFormFiles(form_id)
  [dnl_subs_count, dnl_files_count]
end


#=========MAIN============

# Initialize JotFormAPI Ruby client with api_key
jotform = JotForm.new(api_key, 'https://eu-api.jotform.com')

if jotform
  #puts('******Form Subusers')
  #p jotform.getSubusers()
  #puts('******Form Folders')
  #p jotform.getFolders()
  #puts('******Form Reports')
  #p jotform.getReports()

  downloaded_subs_count = 0
  downloaded_files_count = 0
  if (not form_id) or (form_id.upcase=='ALL')
    puts('===ALL forms will be downloaded..')
    form_id = '*'
    #RU: Если время начала не установлено в команде и файл времени существует, взять время начала из него
    if (not $manual_setted_start_time) and File.exist?($start_time_file)
      File.open($start_time_file, 'r') do |file|
        start_time = file.readline
        start_time.strip if start_time
        if start_time and (start_time.size>=10)
          start_time = Time.parse(start_time)
          $start_from_time = start_time.strftime('%Y-%m-%d %H:%M:%S')
          puts('Readed from ['+$start_time_file+'] start_time='+$start_from_time)
        end
      end
    end

    limit = FormListPortion
    offset = 0
    filter = nil
    #orderby = 'id ASC'
    orderby = 'created_at ASC'  #RU: Отсортировать формы по времени создания

    continue_dnl = true
    while $processing and continue_dnl
      begin
        form_list = jotform.getForms(limit, filter, orderby, offset)
      rescue Exception => e
        puts('Error on getForms() ' + e.message)
        form_list = nil
        $was_errors = true
        $processing = false
      end
      if form_list and $processing
        continue_dnl = (form_list.size==limit)

        puts('***Form list loaded: '+(form_list.size+offset).to_s+'..')
        form_list.each do |form_info|
          aform_id = form_info['id']
          aform_title = form_info['title']
          #Form fields: username, height, url, status, created_at, updated_at, new
          submis_count = form_info['count']
          submis_count = submis_count.to_i if submis_count
          puts('===Form id='+aform_id.to_s + ' "'+aform_title.to_s+'" ('+submis_count.to_s+')')

          #p jotform.getFormQuestions(aform_id)
          #p jotform.getFormProperties(aform_id)
          #p jotform.getFormReports(aform_id)
          #p jotform.getFormSubmissions(aform_id)

          if submis_count.nil? or (submis_count>0)
            #subs_cnt, files_cnt = 0, 0
            subs_cnt, files_cnt = download_form_files(jotform, api_key, aform_id, aform_title, submis_id)
            downloaded_subs_count += subs_cnt
            downloaded_files_count += files_cnt
          end
          break if not $processing
        end
      else
        continue_dnl = false
      end
      offset += limit
    end

    #Save next time ("last created sub time"-24 hour) to txt file if the downloading is complete
    #RU: Сохранить следующее время начала в txt файл, если скачивание было полным
    if $processing and ($last_created_time>0)  #and (not $was_errors)
      next_start_time = Time.at($last_created_time-24*3600).strftime('%Y-%m-%d %H:%M:%S')
      File.open($start_time_file, 'w') do |file|
        file.puts(next_start_time)
      end
      puts('Saved to ['+$start_time_file+'] next start_time='+next_start_time)
    end
  else
    puts('===One form will be downloaded..')
    form_info = jotform.getForm(form_id)
    if form_info
      aform_title = form_info['title']
      puts('===Form id='+form_id.to_s + ' "'+aform_title.to_s+'"')
      downloaded_subs_count, downloaded_files_count = download_form_files(jotform, api_key, form_id, aform_title, submis_id)
    end
  end

  puts('Script interrupted by user.') if (not $was_errors) and (not $processing)
  puts('!There were errors, but script finished!') if $was_errors and $processing
  puts('!!!There were errors, script interrupted!!!') if $was_errors and (not $processing)

  puts("\n######## Total downloaded: " + downloaded_subs_count.to_s + ' pdf and ' + downloaded_files_count.to_s + ' jpg')
  puts('Saving directory: '+ get_base_dir(form_id))
else
  Kernel.abort('Cannot connect to JotForm-server')
end

