# frozen_string_literal: true

Rails.application.routes.draw do
  get '/example' => 'examples#example'
  get '/example_errors' => 'examples#example_errors'
end
