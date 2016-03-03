require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_attributes).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods

  def self.instances
    regions.collect do |region|
      begin
        response = ec2_client(region).describe_vpcs()
        vpcs = []
        response.data.vpcs.each do |vpc|
          hash = vpc_to_hash(region, vpc)
          vpcs << new(hash) if has_name?(hash)
        end
        vpcs
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:cidr_block, :dhcp_options, :instance_tenancy, :region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov if resource[:region] == prov.region
      end
    end
  end

  def self.vpc_to_hash(region, vpc)
    name = name_from_tag(vpc)
    return {} unless name
    {
      name: name,
      id: vpc.vpc_id,
      ensure: :present,
      enable_dns_support: ec2_client(region).describe_vpc_attribute({vpc_id: vpc.vpc_id, attribute: "enableDnsSupport"}).enable_dns_support.value,
      enable_dns_hostnames: ec2_client(region).describe_vpc_attribute({vpc_id: vpc.vpc_id, attribute: "enableDnsHostnames"}).enable_dns_hostnames.value,
      tags: tags_for(vpc),
      dhcp_options: options_name_from_id(region, vpc.dhcp_options_id),
    }
  end

  def exists?
    Puppet.info("Checking for VPC attributes for #{name} in #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Assigning attributes for VPC #{name} in #{target_region}")
    ec2 = ec2_client(target_region)

    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:name]]},
    ])

    vpc_response.data.vpcs.each do |vpc|
      puts vpc
      ec2.modify_vpc_attribute({
        vpc_id: vpc.vpc_id,
          enable_dns_support: {
            value: resource[:enable_dns_support],
          },
      })

      ec2.modify_vpc_attribute({
        vpc_id: vpc.vpc_id,
          enable_dns_hostnames: {
            value: resource[:enable_dns_hostnames],
          },
      })
    end

    vpc_id = vpcs

    # dns support is off on newly created vpcs, so we have to modify them after creation
    # lets just pass whatever we have from the user


  end

  def destroy
    Puppet.info("Deleting VPC #{name} in #{target_region}")
    ec2_client(target_region).delete_vpc(
      vpc_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
