#!/usr/bin/env ruby

# 2020 (c) Invented in JotForm
# 2021 (c) Enhanced by Michael Galyuk (robux@mail.ru)


require 'net/http'
require 'uri'
require 'rubygems'
require 'json'

class JotForm
  attr_accessor :apiKey
  attr_accessor :baseURL
  attr_accessor :apiVersion

  # Create the object
  def initialize(apiKey = nil, baseURL = 'http://api.jotform.com', apiVersion = 'v1')
    @apiKey = apiKey
    @baseURL = baseURL
    @apiVersion = apiVersion
  end

  def _executeHTTPRequest(endpoint, parameters = nil, type = 'GET')
    url = [@baseURL, @apiVersion, endpoint].join('/').concat('?apiKey='+@apiKey)
    if (type == 'GET') and parameters
      parameters.each do |n,v|
        url += '&'+n+'='+v.to_s
      end
    end
    url = URI.parse(url)
    if type == 'GET'
      response = Net::HTTP.get_response(url)
    elsif type == 'POST'
      response = Net::HTTP.post_form(url, parameters)
    end

    if response.kind_of?(Net::HTTPSuccess)
      return JSON.parse(response.body)['content']
    else
      puts(JSON.parse(response.body)['message'])
      return nil
    end
  end

  def _executeGetRequest(endpoint, parameters = [])
    return _executeHTTPRequest(endpoint,parameters, 'GET')
  end

  def _executePostRequest(endpoint, parameters = [])
    return _executeHTTPRequest(endpoint,parameters, 'POST')
  end

  def getUser
    return _executeGetRequest('user')
  end

  def getUsage
    return _executeGetRequest('user/usage');
  end

  #offset=0  - Start of each result set for form list. Useful for pagination.
  #limit=20  - Number of form results. Default is 20. Maximum is 1000.
  #filter={jsonString} - Filters the query results to fetch a specific form range.
  #  Example: filter={"new":"1"}
  #  You can also use gt(greater than), lt(less than), ne(not equal to)
  #  Example: filter={"created_at:gt":"2013-01-01 00:00:00"}
  #orderby=Enum  -  Order results by a form field name: id, username, title,
  #  status(ENABLED, DISABLED, DELETED), created_at, updated_at,
  #  new (unread submissions count), count (all submissions count),
  #  slug (used in form URL).
  #  Example: orderby=created_at
  def getForms(limit=20, filter=nil, orderby=nil, offset=nil)
    params = {}
    params['limit'] = limit if limit
    params['filter'] = filter if filter
    params['orderby'] = orderby if orderby
    params['offset'] = offset if offset
    return _executeGetRequest('user/forms', params)
  end

  def getSubmissions
    return _executeGetRequest('user/submissions')
  end

  def getSubusers
    return _executeGetRequest('user/subusers')
  end

  def getFolders
    return _executeGetRequest('user/folders')
  end

  def getReports
    return _executeGetRequest('user/reports')
  end

  def getSettings
    return _executeGetRequest('user/settings')
  end

  def getHistory
    return _executeGetRequest('user/history')
  end

  def getForm(formID)
    return _executeGetRequest('form/'+ formID)
  end

  def getFormQuestions(formID)
    return _executeGetRequest('form/'+formID+'/questions')
  end

  def getFormQuestion(formID, qid)
    return _executeGetRequest('form/'+formID+'/question/'+qid)
  end

  def getFormProperties(formID)
    return _executeGetRequest('form/'+formID+'/properties')
  end

  def getFormProperty(formID, propertyKey)
    return _executeGetRequest('form/'+formID+'/properties/'+propertyKey)
  end

  def getFormReports(formID)
    return _executeGetRequest('form/'+formID+'/reports')
  end

  #offset=0  - Start of each result set for form list. Useful for pagination
  #limit=20  - Number of results. Default is 20. Maximum is 1000.
  #filter={jsonString}  - Filters the query results to fetch a specific submissions range.
  #  Example: filter={"id:gt":"31974353596870"}
  #  You can also use gt(greater than), lt(less than), ne(not equal to) commands to
  #  get more advanced filtering :
  #  Example: filter={"created_at:gt":"2013-01-01 00:00:00"}
  #orderby=Enum  - Order results by a form field name: id, username, title,
  #  status(ENABLED, DISABLED, DELETED), created_at, updated_at,
  #  new (unread submissions count), count (all submissions count), slug (used in form URL).
  #  Example: orderby=created_at
  def getFormSubmissions(formID, limit=20, filter=nil, orderby=nil, offset=nil)
    params = {}
    params['limit'] = limit if limit
    params['filter'] = filter if filter
    params['orderby'] = orderby if orderby
    params['offset'] = offset if offset
    return _executeGetRequest('form/'+ formID +'/submissions', params)
  end

  def getFormFiles(formID)
    return _executeGetRequest('form/'+formID+'/files')
  end

  def getFormWebhooks(formID)
    return _executeGetRequest('form/'+formID+'/webhooks')
  end

  def getSubmission(sid)
    return _executeGetRequest('submission/'+sid)
  end

  def getReport(reportID)
    return _executeGetRequest('report/'+reportID)
  end

  def getFolder(folderID)
    return _executeGetRequest('folder/'+folderID)
  end

  def createFormWebhook(formID, webhookURL)
    return _executePostRequest('form/'+formID+'/webhooks', {'webhookURL' => webhookURL} );
  end

  def createFormSubmissions(formID, submission)
    return _executePostRequest('form/'+formID+'/submissions', submission);
  end
end

