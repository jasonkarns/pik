require 'win32/registry'
require 'Win32API'
require 'forwardable'

class WindowsEnv

  def self.system
    key    = :HKEY_LOCAL_MACHINE
    subkey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    new(key, subkey)
  end

  def self.user
    key    = :HKEY_CURRENT_USER
    subkey = 'Environment'
    new(key, subkey)
  end

  def initialize(key, subkey)
    @key    = key
    @subkey = subkey
    @reg    = Reg.new
  end

  def set(items)
    items.each{|k,v| self[k] = v }
  end
  
  def [](name)
    @reg.open(@key, @subkey, name)
  end

  def []=(name, value)
    @reg.set(@key, @subkey, name, value)
  end

  def has_key?(key)
    !!self[key]
  end

end

class CommandProcessor < WindowsEnv

  def initialize
    @key    = :HKEY_CURRENT_USER
    @subkey = 'Software\Microsoft\Command Processor'
    @reg    = Reg.new
  end

end

class AutoRun
  extend Forwardable

  def initialize
    @cp = CommandProcessor.new
    @value = @cp['Autorun'].split('&')
  end

  def_delegators :@value, :<<, :reject!

  def save
    p @value.join('&')
    @cp['Autorun'] = @value.join('&')
  end

end

class Reg
  
  def initialize(user=User.new)
    @user = user
  end

  # reads the registry hive that the installer would write to
  # based on user rights
  def install_hkey(subkey, name='')
    @user.admin? ? hklm(subkey,name) : hkcu(subkey,name)
  end

  def hklm(subkey, name='')
    open(:HKEY_LOCAL_MACHINE, subkey, name)
  end
  
  def hkcu(subkey,name='')
    open(:HKEY_CURRENT_USER, subkey, name)
  end
  
  def hkcr(subkey,name='')
    open(:HKEY_CLASSES_ROOT, subkey, name)
  end
  
  def open(key, subkey, name)
    key = Win32::Registry.const_get(key)

    key.open(subkey) do |reg|
      reg_typ, reg_val = reg.read(name) rescue nil
      return reg_val
    end
  end

  def set(key, subkey, name, value)
    key   = Win32::Registry.const_get(key)
    write = Win32::Registry::KEY_WRITE
    key.open(subkey, write) do |reg|
      reg.write_s(name, value)
    end
  end   
end

class User

  IsUserAnAdmin = Win32API.new('shell32', 'IsUserAnAdmin', 'v', 'i')
  
  # the logged on user's name
  def name
    ENV['username']
  end

  # the logged on user's domain
  def domain
    ENV['userdomain']
  end
  
  # determines if the user has admin rights
  # not if the user is a member of the local admins group
  # (allows for nested groups)
  def admin?
    true if IsUserAnAdmin.call.nonzero?
  end

end
    
