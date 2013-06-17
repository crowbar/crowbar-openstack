CREATE TABLE `PCR_manifest` (
  `index` int(11) NOT NULL AUTO_INCREMENT,
  `PCR_number` int(11) DEFAULT NULL,
  `PCR_value` varchar(100) DEFAULT NULL,
  `PCR_desc` varchar(100) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  `create_request_host` varchar(50) DEFAULT NULL,
  `last_update_time` datetime DEFAULT NULL,
  `last_update_request_host` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`index`),
  UNIQUE KEY `PCR_UNIQUE` (`PCR_number`,`PCR_value`)
);

CREATE TABLE `attest_request` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `request_id` varchar(50) DEFAULT NULL,
  `host_name` varchar(50) DEFAULT NULL,
  `request_time` datetime DEFAULT NULL,
  `next_action` int(11) DEFAULT NULL,
  `is_consumed_by_pollingWS` tinyint(1) DEFAULT NULL,
  `audit_log_id` int(11) DEFAULT NULL,
  `host_id` int(11) DEFAULT NULL,
  `request_host` varchar(50) DEFAULT NULL,
  `count` int(11) DEFAULT NULL,
  `PCRMask` varchar(50) DEFAULT NULL,
  `result` int(11) DEFAULT NULL,
  `is_sync` tinyint(1) DEFAULT NULL,
  `validate_time` datetime DEFAULT NULL,  
  PRIMARY KEY (`id`),
  KEY `FK_audit_log_id` (`audit_log_id`),
  KEY `UNIQUE` (`request_id`,`host_id`)
);

create table HOST
(
   ID                   int not null auto_increment,
   HOST_NAME            varchar(50),
   IP_ADDRESS           varchar(50),
   PORT                 varchar(50),
   EMAIL                varchar(100),
   ADDON_CONNECTION_STRING varchar(100),
   DESCRIPTION          varchar(100),
   primary key (ID)
);

create table MLE
(
   ID                   int not null auto_increment,
   OEM_ID               int,
   OS_ID                int,
   NAME                 varchar(50),
   VERSION              varchar(100),
   ATTESTATION_TYPE     varchar(50),
   MLE_TYPE             varchar(50),
   DESCRIPTION          varchar(100),
   primary key (ID)
);

create table HOST_MLE
(
   ID int not null auto_increment,
   HOST_ID int ,
   MLE_ID int ,
   primary key (ID)
);


create table OEM
(
   ID                   int not null auto_increment,
   NAME                 varchar(50),
   DESCRIPTION          varchar(100),
   primary key (ID)
);

create table OS
(
   ID                   int not null auto_increment,
   NAME                 varchar(50),
   VERSION              varchar(50),
   DESCRIPTION          varchar(100),
   primary key (ID)
);

create table PCR_WHITE_LIST
(
   ID                   int not null auto_increment,
   MLE_ID               int,
   PCR_NAME             varchar(10),
   PCR_DIGEST           varchar(100) default NULL,
   primary key (ID)
);

CREATE TABLE `his_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `access` int(11) DEFAULT NULL,
  `active` int(11) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `getsEmail` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
);

CREATE TABLE alerts (
	id int NOT NULL AUTO_INCREMENT,
	audit_fk int,
	status varchar(255),
	assignedTo varchar(255),
	comments text,
  PRIMARY KEY (id)
);

CREATE TABLE audit_log (
	id int NOT NULL AUTO_INCREMENT,
	SID varchar(255),
	machine_name varchar(255),
	timestamp datetime,
	pcr0 varchar(100),
	pcr1 varchar(100),
	pcr4 varchar(100),
	pcr5 varchar(100),
	report text,
	previous_differences varchar(255),
	report_errors text,
	pcr2 varchar(100),
	pcr3 varchar(100),
	pcr6 varchar(100),
	pcr7 varchar(100),
	pcr8 varchar(100),
	pcr9 varchar(100),
	pcr10 varchar(100),
	pcr11 varchar(100),
	pcr12 varchar(100),
	pcr13 varchar(100),
	pcr14 varchar(100),
	pcr15 varchar(100),
	pcr16 varchar(100),
	pcr17 varchar(100),
	pcr18 varchar(100),
	pcr19 varchar(100),
	pcr20 varchar(100),
	pcr21 varchar(100),
	pcr22 varchar(100),
	pcr23 varchar(100),
	machine_id int,
	pcr_select varchar(100),
	nonce varchar(100),
	signature_verified tinyint NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);

CREATE TABLE machine_cert (
	id int NOT NULL AUTO_INCREMENT,
	machine_name varchar(50),
	certificate text,
	active tinyint NOT NULL DEFAULT 1,
	privacy_ca_id int,
	timestamp datetime,
	last_poll datetime,
	next_action int,
	poll_args varchar(255),
  PRIMARY KEY (id)
);

CREATE TABLE system_constants (
	id int NOT NULL AUTO_INCREMENT,
	key_id varchar(255),
	value text,
	description text,
  PRIMARY KEY (id)
);

insert into system_constants (key_id, value) values ('default_delay', 10000);
