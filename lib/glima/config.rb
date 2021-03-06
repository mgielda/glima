module Glima
  class Config < Clian::Config::Toplevel

    class General < Clian::Config::Element
      define_syntax :client_id => String,
                    :client_secret => String,
                    :cache_directory => String,
                    :zip_passwords_file => String,
                    :default_user => String
    end # class General

    define_syntax :general => General

  end # Config
end # Glima
