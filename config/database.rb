HOST = 'localhost'
USER = 'username'
PASS = 'password'
DBNAME = 'dbname'

def db_connect()
  return Kwery.connect(HOST, USER, PASS, DBNAME)
end
