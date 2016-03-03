require_relative '../../puppet_x/puppetlabs/property/tag.rb'

Puppet::Type.newtype(:ec2_vpc_attributes) do
  @doc = 'A type representing attributes assigned to an AWS VPC.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the VPC.'
    validate do |value|
      fail 'a VPC must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:region) do
    desc 'The region in which to address the VPC.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:enable_dns_support) do
    desc 'Enable DNS Support for this VPC.'
    defaultto 'true'
  end

  newproperty(:enable_dns_hostnames) do
    desc 'Enable DNS Hostnames for this VPC.'
    defaultto 'true'
  end

  autorequire(:ec2_vpc) do
    self[:name]
  end
end
