
--
-- Copyright (c) 2010-2019 Todd Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--
-- Copyright (c) 2005-2010, Vonage Holdings Corp.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY VONAGE HOLDINGS CORP. ''AS IS'' AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL VONAGE HOLDINGS CORP. BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--


--
-- $Id$
--

CREATE schema jazzhands;
COMMENT ON SCHEMA jazzhands IS 'https://github.com/JazzHandsCMDB/jazzhands';
ALTER USER jazzhands SET search_path = jazzhands;
set search_path = jazzhands;

--
--


/***********************************************
 * Table: account
 ***********************************************/

CREATE TABLE account
( 
	account_id           serial  NOT NULL ,
	login                varchar(50)  NOT NULL ,
	person_id            integer  NOT NULL ,
	company_id           integer  NOT NULL ,
	is_enabled           char(1)  NOT NULL ,
	account_realm_id     integer  NOT NULL ,
	account_status       varchar(50)  NOT NULL ,
	account_role         varchar(50)  NOT NULL ,
	account_type         varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account
	ADD CONSTRAINT "pk_account_id" PRIMARY KEY (account_id);

ALTER TABLE account
	ADD CONSTRAINT "ak_acct_acctid_realm_id" UNIQUE (account_id,account_realm_id);

ALTER TABLE account
	ADD CONSTRAINT "ak_uq_account_lgn_realm" UNIQUE (account_realm_id,login);

CREATE INDEX xif8account ON account
( 
	account_realm_id
);

CREATE INDEX xif9account ON account
( 
	account_role
);

CREATE INDEX xif11account ON account
( 
	company_id,
	person_id
);

CREATE INDEX xif12account ON account
( 
	person_id,
	company_id,
	account_realm_id
);

CREATE INDEX idx_account_account_status ON account
( 
	account_status
);

CREATE INDEX idx_account_account_tpe ON account
( 
	account_type
);

/***********************************************
 * Table: account_assigned_certificate
 ***********************************************/

CREATE TABLE account_assigned_certificate
( 
	account_id           integer  NOT NULL ,
	x509_cert_id         integer  NOT NULL ,
	x509_key_usg         varchar(50)  NOT NULL ,
	key_usage_reason_for_assign varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_assigned_certificate
	ADD CONSTRAINT "pk_account_assigned_cer" PRIMARY KEY (account_id,x509_cert_id,x509_key_usg);

/***********************************************
 * Table: account_auth_log
 ***********************************************/

CREATE TABLE account_auth_log
( 
	account_id           integer  NOT NULL ,
	account_auth_ts      timestamp without time zone  NOT NULL ,
	auth_resource        character varying(50)  NOT NULL ,
	account_auth_seq     integer  NOT NULL ,
	was_auth_success     CHAR(1)  NOT NULL ,
	auth_resource_instance varchar(50)  NOT NULL ,
	auth_origin          varchar(50)  NOT NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL 
);

ALTER TABLE account_auth_log
	ADD CONSTRAINT "pk_account_auth_log" PRIMARY KEY (account_id,account_auth_ts,auth_resource,account_auth_seq);

CREATE INDEX xieacctauthlog_ts_arsrc ON account_auth_log
( 
	account_auth_ts,
	auth_resource
);

/***********************************************
 * Table: account_collection
 ***********************************************/

CREATE TABLE account_collection
( 
	account_collection_id serial  NOT NULL ,
	account_collection_name varchar(255)  NOT NULL ,
	account_collection_type varchar(50)  NOT NULL ,
	external_id          varchar(255)  NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_collection
	ADD CONSTRAINT "pk_account_collection" PRIMARY KEY (account_collection_id);

ALTER TABLE account_collection
	ADD CONSTRAINT "uq_acct_collection_name" UNIQUE (account_collection_name,account_collection_type);

CREATE INDEX xif_acctcol_acctcoltype ON account_collection
( 
	account_collection_type
);

CREATE TABLE account_collection_account
( 
	account_collection_id integer  NOT NULL ,
	account_id           integer  NOT NULL ,
	account_collection_relation varchar(50)  NULL ,
	account_id_rank      integer  NULL ,
	start_date           timestamp without time zone  NULL ,
	finish_date          timestamp without time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_collection_account
	ADD CONSTRAINT "pk_account_collection_user" PRIMARY KEY (account_collection_id,account_id);

ALTER TABLE account_collection_account
	ADD CONSTRAINT "ak_acctcol_acct_rank" UNIQUE (account_collection_id,account_id_rank);

CREATE INDEX xifacctcollacct_ac_relate ON account_collection_account
( 
	account_collection_relation
);

/***********************************************
 * Table: account_collection_hier
 ***********************************************/

CREATE TABLE account_collection_hier
( 
	account_collection_id integer  NOT NULL ,
	child_account_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_collection_hier
	ADD CONSTRAINT "pk_account_collection_hier" PRIMARY KEY (account_collection_id,child_account_collection_id);

/***********************************************
 * Table: account_collection_type_relation
 ***********************************************/

CREATE TABLE account_collection_type_relation
( 
	account_collection_relation character varying(50)  NOT NULL ,
	account_collection_type character varying(50)  NOT NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_collection_type_relation
	ADD CONSTRAINT "pk_account_coll_type_relation" PRIMARY KEY (account_collection_relation,account_collection_type);

CREATE INDEX xifacct_coll_rel_type_rel ON account_collection_type_relation
( 
	account_collection_relation
);

CREATE INDEX xifacct_coll_rel_type_type ON account_collection_type_relation
( 
	account_collection_type
);

/***********************************************
 * Table: account_password
 ***********************************************/

CREATE TABLE account_password
( 
	account_id           integer  NOT NULL ,
	account_realm_id     integer  NOT NULL ,
	password_type        character varying(50)  NOT NULL ,
	password             varchar(255)  NOT NULL ,
	change_time          timestamp with time zone  NULL ,
	expire_time          timestamp with time zone  NULL ,
	unlock_time          timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_password
	ADD CONSTRAINT "pk_accunt_password" PRIMARY KEY (account_id,account_realm_id,password_type);

CREATE INDEX xif_acctpwd_acct_id ON account_password
( 
	account_id,
	account_realm_id
);

CREATE INDEX xif_acct_pwd_acct_realm ON account_password
( 
	account_realm_id
);

CREATE INDEX xif_acct_pwd_relm_type ON account_password
( 
	password_type,
	account_realm_id
);

/***********************************************
 * Table: account_realm
 ***********************************************/

CREATE TABLE account_realm
( 
	account_realm_id     serial  NOT NULL ,
	account_realm_name   varchar(100)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_realm
	ADD CONSTRAINT "pk_account_realm" PRIMARY KEY (account_realm_id);

CREATE INDEX idx_account_realm_ar_name ON account_realm
( 
	account_realm_name
);

/***********************************************
 * Table: account_realm_account_collection_type
 ***********************************************/

CREATE TABLE account_realm_account_collection_type
( 
	account_realm_id     integer  NOT NULL ,
	account_collection_type character varying(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_realm_account_collection_type
	ADD CONSTRAINT "pk_account_realm_acct_coll_type" PRIMARY KEY (account_realm_id,account_collection_type);

CREATE INDEX xif1_acct_realm_acct_coll_typ ON account_realm_account_collection_type
( 
	account_collection_type
);

CREATE INDEX xif2_acct_realm_acct_coll_arid ON account_realm_account_collection_type
( 
	account_realm_id
);

/***********************************************
 * Table: account_realm_company
 ***********************************************/

CREATE TABLE account_realm_company
( 
	account_realm_id     integer  NOT NULL ,
	company_id           integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_realm_company
	ADD CONSTRAINT "pk_account_realm_company" PRIMARY KEY (account_realm_id,company_id);

CREATE INDEX xif1account_realm_company ON account_realm_company
( 
	company_id
);

CREATE INDEX xif2account_realm_company ON account_realm_company
( 
	account_realm_id
);

/***********************************************
 * Table: account_realm_password_type
 ***********************************************/

CREATE TABLE account_realm_password_type
( 
	password_type        character varying(50)  NOT NULL ,
	account_realm_id     integer  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_realm_password_type
	ADD CONSTRAINT "pk_account_realm_password_type" PRIMARY KEY (password_type,account_realm_id);

CREATE INDEX xif_acrlm_acct_rlm_id ON account_realm_password_type
( 
	account_realm_id
);

CREATE INDEX xif_acrlm_pwd_type ON account_realm_password_type
( 
	password_type
);

/***********************************************
 * Table: account_ssh_key
 ***********************************************/

CREATE TABLE account_ssh_key
( 
	account_id           integer  NOT NULL ,
	ssh_key_id           integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_ssh_key
	ADD CONSTRAINT "pk_account_ssh_key" PRIMARY KEY (account_id,ssh_key_id);

CREATE INDEX xif2account_ssh_key ON account_ssh_key
( 
	ssh_key_id
);

CREATE INDEX xif1account_ssh_key ON account_ssh_key
( 
	account_id
);

/***********************************************
 * Table: account_token
 ***********************************************/

CREATE TABLE account_token
( 
	account_token_id     serial  NOT NULL ,
	account_id           integer  NOT NULL ,
	token_id             integer  NOT NULL ,
	issued_date          timestamp with time zone  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_token
	ADD CONSTRAINT "pk_account_token" PRIMARY KEY (account_token_id);

ALTER TABLE account_token
	ADD CONSTRAINT "ak_account_token_tken_acct" UNIQUE (account_id,token_id);

/***********************************************
 * Table: account_unix_info
 ***********************************************/

CREATE TABLE account_unix_info
( 
	account_id           integer  NOT NULL ,
	unix_uid             integer  NOT NULL ,
	unix_group_account_collection_id integer  NOT NULL ,
	shell                varchar(255)  NOT NULL ,
	default_home         varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE account_unix_info
	ADD CONSTRAINT "pk_account_unix_info" PRIMARY KEY (account_id);

ALTER TABLE account_unix_info
	ADD CONSTRAINT "ak_account_unix_info_unix_uid" UNIQUE (unix_uid);

CREATE INDEX xif3account_unix_info ON account_unix_info
( 
	unix_group_account_collection_id
);

CREATE INDEX xif4account_unix_info ON account_unix_info
( 
	unix_group_account_collection_id,
	account_id
);

/***********************************************
 * Table: appaal
 ***********************************************/

CREATE TABLE appaal
( 
	appaal_id            serial  NOT NULL ,
	appaal_name          varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE appaal
	ADD CONSTRAINT "pk_appaal" PRIMARY KEY (appaal_id);

CREATE UNIQUE INDEX uq_appaal_name ON appaal
( 
	appaal_name
);

/***********************************************
 * Table: appaal_instance
 ***********************************************/

CREATE TABLE appaal_instance
( 
	appaal_instance_id   serial  NOT NULL ,
	appaal_id            integer  NULL ,
	service_environment_id integer  NOT NULL ,
	file_mode            integer  NOT NULL ,
	file_owner_account_id integer  NOT NULL ,
	file_group_account_collection_id integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE appaal_instance
	ADD CONSTRAINT "pk_appaal_instance" PRIMARY KEY (appaal_instance_id);

CREATE INDEX xifappaal_inst_filgrpacctcolid ON appaal_instance
( 
	file_group_account_collection_id
);

/***********************************************
 * Table: appaal_instance_device_collection
 ***********************************************/

CREATE TABLE appaal_instance_device_collection
( 
	device_collection_id integer  NOT NULL ,
	appaal_instance_id   integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE appaal_instance_device_collection
	ADD CONSTRAINT "pk_appaal_instance_device_coll" PRIMARY KEY (device_collection_id,appaal_instance_id);

/***********************************************
 * Table: appaal_instance_property
 ***********************************************/

CREATE TABLE appaal_instance_property
( 
	appaal_instance_id   integer  NOT NULL ,
	app_key              varchar(50)  NOT NULL ,
	appaal_group_name    varchar(50)  NOT NULL ,
	appaal_group_rank    varchar(50)  NOT NULL ,
	app_value            varchar(4000)  NOT NULL ,
	encryption_key_id    integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE appaal_instance_property
	ADD CONSTRAINT "pk_appaal_instance_property" PRIMARY KEY (appaal_instance_id,app_key,appaal_group_name,appaal_group_rank);

ALTER TABLE appaal_instance_property
	ADD CONSTRAINT "ak_appaal_instance_idkeyrank" UNIQUE (appaal_instance_id,app_key,appaal_group_rank);

CREATE INDEX xif4appaal_instance_property ON appaal_instance_property
( 
	appaal_group_name
);

CREATE INDEX ind_aaiprop_key_value ON appaal_instance_property
( 
	app_key ,
	app_value
);

/***********************************************
 * Table: approval_instance
 ***********************************************/

CREATE TABLE approval_instance
( 
	approval_instance_id serial  NOT NULL ,
	approval_process_id  integer  NULL ,
	approval_instance_name varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	approval_start       timestamp with time zone  NOT NULL ,
	approval_end         timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_instance
	ADD CONSTRAINT "pk_approval_instance" PRIMARY KEY (approval_instance_id);

CREATE INDEX xif1approval_instance ON approval_instance
( 
	approval_process_id
);

/***********************************************
 * Table: approval_instance_item
 ***********************************************/

CREATE TABLE approval_instance_item
( 
	approval_instance_item_id serial  NOT NULL ,
	approval_instance_link_id integer  NOT NULL ,
	approval_instance_step_id integer  NOT NULL ,
	next_approval_instance_item_id integer  NULL ,
	approved_category    varchar(255)  NOT NULL ,
	approved_label       varchar(255)  NULL ,
	approved_lhs         varchar(255)  NULL ,
	approved_rhs         varchar(255)  NULL ,
	is_approved          char(1)  NULL ,
	approved_account_id  integer  NULL ,
	approval_note        text  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_instance_item
	ADD CONSTRAINT "pk_approval_instance_item" PRIMARY KEY (approval_instance_item_id);

CREATE INDEX xif1approval_instance_item ON approval_instance_item
( 
	approval_instance_step_id
);

CREATE INDEX xif2approval_instance_item ON approval_instance_item
( 
	approval_instance_link_id
);

CREATE INDEX xif3approval_instance_item ON approval_instance_item
( 
	next_approval_instance_item_id
);

CREATE INDEX xif4approval_instance_item ON approval_instance_item
( 
	approved_account_id
);

/***********************************************
 * Table: approval_instance_link
 ***********************************************/

CREATE TABLE approval_instance_link
( 
	approval_instance_link_id serial  NOT NULL ,
	acct_collection_acct_seq_id integer  NULL ,
	person_company_seq_id integer  NULL ,
	property_seq_id      integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_instance_link
	ADD CONSTRAINT "pk_approval_instance_link" PRIMARY KEY (approval_instance_link_id);

/***********************************************
 * Table: approval_instance_step
 ***********************************************/

CREATE TABLE approval_instance_step
( 
	approval_instance_step_id serial  NOT NULL ,
	approval_instance_id integer  NOT NULL ,
	approval_process_chain_id integer  NOT NULL ,
	approval_instance_step_name varchar(50)  NOT NULL ,
	approval_instance_step_due timestamp with time zone  NOT NULL ,
	approval_type        varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	approval_instance_step_start timestamp with time zone  NOT NULL ,
	approval_instance_step_end timestamp with time zone  NULL ,
	approver_account_id  integer  NOT NULL ,
	external_reference_name varchar(255)  NULL ,
	is_completed         char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_instance_step
	ADD CONSTRAINT "pk_approval_instance_step" PRIMARY KEY (approval_instance_step_id);

CREATE INDEX xif1approval_instance_step ON approval_instance_step
( 
	approval_instance_id
);

CREATE INDEX xif4approval_instance_step ON approval_instance_step
( 
	approval_type
);

CREATE INDEX xif5approval_instance_step ON approval_instance_step
( 
	approval_process_chain_id
);

CREATE INDEX xif2approval_instance_step ON approval_instance_step
( 
	approver_account_id
);

/***********************************************
 * Table: approval_instance_step_notify
 ***********************************************/

CREATE TABLE approval_instance_step_notify
( 
	approv_instance_step_notify_id serial  NOT NULL ,
	approval_instance_step_id integer  NOT NULL ,
	approval_notify_type varchar(50)  NOT NULL ,
	account_id           integer  NOT NULL ,
	approval_notify_whence timestamp with time zone  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT "pk_approval_instance_step_notify" PRIMARY KEY (approv_instance_step_notify_id);

CREATE INDEX xif1approval_instance_step_notify ON approval_instance_step_notify
( 
	approval_notify_type
);

CREATE INDEX xif2approval_instance_step_notify ON approval_instance_step_notify
( 
	approval_instance_step_id
);

CREATE INDEX xif3approval_instance_step_notify ON approval_instance_step_notify
( 
	account_id
);

/***********************************************
 * Table: approval_process
 ***********************************************/

CREATE TABLE approval_process
( 
	approval_process_id  serial  NOT NULL ,
	approval_process_name varchar(50)  NOT NULL ,
	approval_process_type varchar(50)  NULL ,
	description          varchar(255)  NULL ,
	first_approval_process_chain_id integer  NOT NULL ,
	property_name_collection_id integer  NOT NULL ,
	approval_expiration_action varchar(50)  NOT NULL ,
	attestation_frequency varchar(50)  NULL ,
	attestation_offset   integer  NULL ,
	max_escalation_level integer  NULL ,
	escalation_delay     varchar(50)  NULL ,
	escalation_reminder_gap integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_process
	ADD CONSTRAINT "pk_approval_process" PRIMARY KEY (approval_process_id);

CREATE INDEX xif1approval_process ON approval_process
( 
	property_name_collection_id
);

CREATE INDEX xif2approval_process ON approval_process
( 
	approval_process_type
);

CREATE INDEX xif3approval_process ON approval_process
( 
	approval_expiration_action
);

CREATE INDEX xif4approval_process ON approval_process
( 
	attestation_frequency
);

CREATE INDEX xif5approval_process ON approval_process
( 
	first_approval_process_chain_id
);

/***********************************************
 * Table: approval_process_chain
 ***********************************************/

CREATE TABLE approval_process_chain
( 
	approval_process_chain_id serial  NOT NULL ,
	approval_process_chain_name varchar(50)  NOT NULL ,
	approval_chain_response_period varchar(50)  NULL ,
	description          varchar(255)  NULL ,
	message              varchar(4096)  NULL ,
	email_message        varchar(4096)  NULL ,
	email_subject_prefix varchar(50)  NULL ,
	email_subject_suffix varchar(50)  NULL ,
	max_escalation_level integer  NULL ,
	escalation_delay     integer  NULL ,
	escalation_reminder_gap integer  NULL ,
	approving_entity     varchar(50)  NULL ,
	refresh_all_data     char(1)  NOT NULL ,
	accept_app_process_chain_id integer  NULL ,
	reject_app_process_chain_id integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE approval_process_chain
	ADD CONSTRAINT "pk_approval_process_chain" PRIMARY KEY (approval_process_chain_id);

CREATE INDEX xif1approval_process_chain ON approval_process_chain
( 
	approval_chain_response_period
);

CREATE INDEX xif2approval_process_chain ON approval_process_chain
( 
	accept_app_process_chain_id
);

CREATE INDEX xif3approval_process_chain ON approval_process_chain
( 
	accept_app_process_chain_id
);

/***********************************************
 * Table: asset
 ***********************************************/

CREATE TABLE asset
( 
	asset_id             serial  NOT NULL ,
	component_id         integer  NULL ,
	description          varchar(255)  NULL ,
	contract_id          integer  NULL ,
	serial_number        varchar(255)  NULL ,
	part_number          varchar(255)  NULL ,
	asset_tag            varchar(255)  NULL ,
	ownership_status     character varying(50)  NOT NULL ,
	lease_expiration_date timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE asset
	ADD CONSTRAINT "pk_asset" PRIMARY KEY (asset_id);

ALTER TABLE asset
	ADD CONSTRAINT "ak_asset_component_id" UNIQUE (component_id);

CREATE INDEX xif_asset_comp_id ON asset
( 
	component_id
);

CREATE INDEX xif_asset_contract_id ON asset
( 
	contract_id
);

CREATE INDEX xif_asset_ownshp_stat ON asset
( 
	ownership_status
);

/***********************************************
 * Table: badge
 ***********************************************/

CREATE TABLE badge
( 
	card_number          integer  NOT NULL ,
	badge_type_id        integer  NOT NULL ,
	badge_status         character varying(50)  NOT NULL ,
	date_assigned        timestamp with time zone  NULL ,
	date_reclaimed       timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE badge
	ADD CONSTRAINT "pk_badge" PRIMARY KEY (card_number);

/***********************************************
 * Table: badge_type
 ***********************************************/

CREATE TABLE badge_type
( 
	badge_type_id        serial  NOT NULL ,
	badge_type_name      varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	badge_color          varchar(50)  NOT NULL ,
	badge_template_name  varchar(255)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE badge_type
	ADD CONSTRAINT "pk_badge_type" PRIMARY KEY (badge_type_id);

ALTER TABLE badge_type
	ADD CONSTRAINT "ak_uq_badge_color_badge_ty" UNIQUE (badge_color);

ALTER TABLE badge_type
	ADD CONSTRAINT "ak_uq_badge_type_name_badge_ty" UNIQUE (badge_type_name);

/***********************************************
 * Table: certificate_signing_request
 ***********************************************/

CREATE TABLE certificate_signing_request
( 
	certificate_signing_request_id serial  NOT NULL ,
	friendly_name        varchar(255)  NOT NULL ,
	subject              varchar(255)  NOT NULL ,
	certificate_signing_request text  NOT NULL ,
	private_key_id       integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE certificate_signing_request
	ADD CONSTRAINT "pk_certificate_signing_request" PRIMARY KEY (certificate_signing_request_id);

CREATE INDEX fk_csr_pvtkeyid ON certificate_signing_request
( 
	private_key_id
);

/***********************************************
 * Table: chassis_location
 ***********************************************/

CREATE TABLE chassis_location
( 
	chassis_location_id  serial  NOT NULL ,
	chassis_device_type_id integer  NOT NULL ,
	device_type_module_name character varying(255)  NOT NULL ,
	chassis_device_id    integer  NOT NULL ,
	module_device_type_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE chassis_location
	ADD CONSTRAINT "pk_chassis_location" PRIMARY KEY (chassis_location_id);

ALTER TABLE chassis_location
	ADD CONSTRAINT "ak_chass_dev_module_name" UNIQUE (chassis_device_id,device_type_module_name);

ALTER TABLE chassis_location
	ADD CONSTRAINT "ak_chass_loc_module_enforce" UNIQUE (chassis_location_id,chassis_device_id,module_device_type_id);

CREATE INDEX xif2chassis_location ON chassis_location
( 
	chassis_device_type_id,
	device_type_module_name
);

CREATE INDEX xif3chassis_location ON chassis_location
( 
	module_device_type_id
);

CREATE INDEX xif4chassis_location ON chassis_location
( 
	chassis_device_id
);

CREATE INDEX xif5chassis_location ON chassis_location
( 
	module_device_type_id,
	chassis_device_type_id,
	device_type_module_name
);

/***********************************************
 * Table: circuit
 ***********************************************/

CREATE TABLE circuit
( 
	circuit_id           serial  NOT NULL ,
	vendor_company_id    integer  NULL ,
	vendor_circuit_id_str varchar(255)  NULL ,
	aloc_lec_company_id  integer  NULL ,
	aloc_lec_circuit_id_str varchar(255)  NULL ,
	aloc_parent_circuit_id integer  NULL ,
	zloc_lec_company_id  integer  NULL ,
	zloc_lec_circuit_id_str varchar(255)  NULL ,
	zloc_parent_circuit_id integer  NULL ,
	is_locally_managed   CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE circuit
	ADD CONSTRAINT "pk_circuit" PRIMARY KEY (circuit_id);

CREATE INDEX xif9circuit ON circuit
( 
	vendor_company_id
);

CREATE INDEX xif10circuit ON circuit
( 
	aloc_lec_company_id
);

CREATE INDEX xif11circuit ON circuit
( 
	zloc_lec_company_id
);

CREATE INDEX idx_circuit_end1parentcircid ON circuit
( 
	aloc_parent_circuit_id
);

CREATE INDEX idx_circuit_end2parentcircid ON circuit
( 
	zloc_parent_circuit_id
);

CREATE INDEX idx_circuit_islclmngd ON circuit
( 
	is_locally_managed
);

/***********************************************
 * Table: company
 ***********************************************/

CREATE TABLE company
( 
	company_id           serial  NOT NULL ,
	company_name         varchar(255)  NOT NULL ,
	company_short_name   varchar(50)  NULL ,
	parent_company_id    integer  NULL ,
	description          varchar(4000)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE company
	ADD CONSTRAINT "pk_company" PRIMARY KEY (company_id);

CREATE INDEX xif1company ON company
( 
	parent_company_id
);

/***********************************************
 * Table: company_collection
 ***********************************************/

CREATE TABLE company_collection
( 
	company_collection_id serial  NOT NULL ,
	company_collection_name varchar(255)  NOT NULL ,
	company_collection_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE company_collection
	ADD CONSTRAINT "pk_company_collection" PRIMARY KEY (company_collection_id);

ALTER TABLE company_collection
	ADD CONSTRAINT "ak_company_collection_namtyp" UNIQUE (company_collection_name,company_collection_type);

CREATE INDEX xifcomp_coll_com_coll_type ON company_collection
( 
	company_collection_type
);

/***********************************************
 * Table: company_collection_company
 ***********************************************/

CREATE TABLE company_collection_company
( 
	company_collection_id integer  NOT NULL ,
	company_id           integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE company_collection_company
	ADD CONSTRAINT "pk_company_collection_company" PRIMARY KEY (company_collection_id,company_id);

CREATE INDEX xifcompany_coll_company_coll_id ON company_collection_company
( 
	company_collection_id
);

CREATE INDEX xifcompany_coll_company_id ON company_collection_company
( 
	company_id
);

/***********************************************
 * Table: company_collection_hier
 ***********************************************/

CREATE TABLE company_collection_hier
( 
	company_collection_id integer  NOT NULL ,
	child_company_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE company_collection_hier
	ADD CONSTRAINT "pk_company_collection_hier" PRIMARY KEY (company_collection_id,child_company_collection_id);

CREATE INDEX xifcomp_coll_comp_coll_id ON company_collection_hier
( 
	company_collection_id
);

CREATE INDEX xifcomp_coll_comp_coll_kid_id ON company_collection_hier
( 
	child_company_collection_id
);

/***********************************************
 * Table: company_type
 ***********************************************/

CREATE TABLE company_type
( 
	company_id           integer  NOT NULL ,
	company_type         character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE company_type
	ADD CONSTRAINT "pk_company_type" PRIMARY KEY (company_id,company_type);

CREATE INDEX xif1company_type ON company_type
( 
	company_id
);

CREATE INDEX xif2company_type ON company_type
( 
	company_type
);

/***********************************************
 * Table: component
 ***********************************************/

CREATE TABLE component
( 
	component_id         serial  NOT NULL ,
	component_type_id    integer  NOT NULL ,
	component_name       varchar(255)  NULL ,
	rack_location_id     integer  NULL ,
	parent_slot_id       integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE component
	ADD CONSTRAINT "pk_component" PRIMARY KEY (component_id);

ALTER TABLE component
	ADD CONSTRAINT "ak_component_component_type_id" UNIQUE (component_id,component_type_id);

ALTER TABLE component
	ADD CONSTRAINT "ak_component_parent_slot_id" UNIQUE (parent_slot_id);

CREATE INDEX xif_component_comp_type_id ON component
( 
	component_type_id
);

CREATE INDEX xif_component_prnt_slt_id ON component
( 
	parent_slot_id
);

CREATE INDEX xif_component_rack_loc_id ON component
( 
	rack_location_id
);

/***********************************************
 * Table: component_property
 ***********************************************/

CREATE TABLE component_property
( 
	component_property_id serial  NOT NULL ,
	component_function   character varying(50)  NULL ,
	component_type_id    integer  NULL ,
	component_id         integer  NULL ,
	inter_component_connection_id integer  NULL ,
	slot_function        character varying(50)  NULL ,
	slot_type_id         integer  NULL ,
	slot_id              integer  NULL ,
	component_property_name character varying(50)  NULL ,
	component_property_type varchar(50)  NULL ,
	property_value       varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE component_property
	ADD CONSTRAINT "pk_component_property" PRIMARY KEY (component_property_id);

CREATE INDEX xif8component_property ON component_property
( 
	inter_component_connection_id
);

CREATE INDEX xif_comp_prop_cmp_id ON component_property
( 
	component_id
);

CREATE INDEX xif_comp_prop_comp_func ON component_property
( 
	component_function
);

CREATE INDEX xif_comp_prop_comp_typ_id ON component_property
( 
	component_type_id
);

CREATE INDEX xif_comp_prop_prop_nmty ON component_property
( 
	component_property_name,
	component_property_type
);

CREATE INDEX xif_comp_prop_sltfuncid ON component_property
( 
	slot_function
);

CREATE INDEX xif_comp_prop_slt_slt_id ON component_property
( 
	slot_id 
);

CREATE INDEX xif_comp_prop_slt_typ_id ON component_property
( 
	slot_type_id
);

/***********************************************
 * Table: component_type
 ***********************************************/

CREATE TABLE component_type
( 
	component_type_id    serial  NOT NULL ,
	company_id           integer  NULL ,
	model                varchar(255)  NULL ,
	slot_type_id         integer  NULL ,
	description          varchar(255)  NULL ,
	part_number          varchar(255)  NULL ,
	is_removable         char(1)  NOT NULL ,
	asset_permitted      char(1)  NOT NULL ,
	is_rack_mountable    char(1)  NOT NULL ,
	is_virtual_component char(1)  NOT NULL ,
	size_units           varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE component_type
	ADD CONSTRAINT "pk_component_type" PRIMARY KEY (component_type_id);

CREATE INDEX xif_component_type_company_id ON component_type
( 
	company_id
);

CREATE INDEX xif_component_type_slt_type_id ON component_type
( 
	slot_type_id
);

/***********************************************
 * Table: component_type_component_function
 ***********************************************/

CREATE TABLE component_type_component_function
( 
	component_function   character varying(50)  NOT NULL ,
	component_type_id    integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE component_type_component_function
	ADD CONSTRAINT "pk_component_type_component_func" PRIMARY KEY (component_function,component_type_id);

CREATE INDEX xif_cmptypcf_comp_func ON component_type_component_function
( 
	component_function
);

CREATE INDEX xif_cmptypecf_comp_typ_id ON component_type_component_function
( 
	component_type_id
);

/***********************************************
 * Table: component_type_slot_template
 ***********************************************/

CREATE TABLE component_type_slot_template
( 
	component_type_slot_tmplt_id serial  NOT NULL ,
	component_type_id    integer  NOT NULL ,
	slot_type_id         integer  NOT NULL ,
	slot_name_template   varchar(50)  NOT NULL ,
	child_slot_name_template varchar(50)  NULL ,
	child_slot_offset    integer  NULL ,
	slot_index           integer  NULL ,
	physical_label       varchar(50)  NULL ,
	slot_x_offset        integer  NULL ,
	slot_y_offset        INTEGER  NULL ,
	slot_z_offset        integer  NULL ,
	slot_side            varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE component_type_slot_template
	ADD CONSTRAINT "pk_component_type_slot_tmplt" PRIMARY KEY (component_type_slot_tmplt_id);

CREATE INDEX xif_comp_typ_slt_tmplt_cmptypid ON component_type_slot_template
( 
	component_type_id
);

CREATE INDEX xif_comp_typ_slt_tmplt_slttypid ON component_type_slot_template
( 
	slot_type_id
);

/***********************************************
 * Table: contract
 ***********************************************/

CREATE TABLE contract
( 
	contract_id          serial  NOT NULL ,
	company_id           integer  NOT NULL ,
	contract_name        varchar(255)  NOT NULL ,
	vendor_contract_name varchar(255)  NULL ,
	description          varchar(255)  NULL ,
	contract_termination_date timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE contract
	ADD CONSTRAINT "pk_contract" PRIMARY KEY (contract_id);

CREATE INDEX xifcontract_company_id ON contract
( 
	company_id
);

/***********************************************
 * Table: contract_type
 ***********************************************/

CREATE TABLE contract_type
( 
	contract_id          integer  NOT NULL ,
	contract_type        character varying(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE contract_type
	ADD CONSTRAINT "pk_contract_type" PRIMARY KEY (contract_id,contract_type);

CREATE INDEX xif_contract_contract_id ON contract_type
( 
	contract_id
);

CREATE INDEX xif_contract_contract_type ON contract_type
( 
	contract_type
);

/***********************************************
 * Table: department
 ***********************************************/

CREATE TABLE department
( 
	account_collection_id integer  NOT NULL ,
	company_id           integer  NOT NULL ,
	manager_account_id   integer  NULL ,
	is_active            CHAR(1)  NOT NULL ,
	dept_code            varchar(30)  NULL ,
	cost_center_name     varchar(255)  NULL ,
	cost_center_number   integer  NULL ,
	default_badge_type_id integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE department
	ADD CONSTRAINT "pk_deptid" PRIMARY KEY (account_collection_id);

CREATE UNIQUE INDEX xif5department ON department
( 
	account_collection_id
);

CREATE INDEX xif6department ON department
( 
	manager_account_id
);

CREATE INDEX idx_dept_deptcode_companyid ON department
( 
	dept_code,
	company_id
);

CREATE INDEX xifdept_badge_type ON department
( 
	default_badge_type_id
);

CREATE INDEX xifdept_company ON department
( 
	company_id
);

/***********************************************
 * Table: device
 ***********************************************/

CREATE TABLE device
( 
	device_id            serial  NOT NULL ,
	component_id         integer  NULL ,
	device_type_id       integer  NOT NULL ,
	device_name          varchar(255)  NULL ,
	site_code            character varying(50)  NULL ,
	identifying_dns_record_id integer  NULL ,
	host_id              varchar(255)  NULL ,
	physical_label       varchar(255)  NULL ,
	rack_location_id     integer  NULL ,
	chassis_location_id  integer  NULL ,
	parent_device_id     integer  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	device_status        varchar(50)  NOT NULL ,
	operating_system_id  integer  NOT NULL ,
	service_environment_id integer  NOT NULL ,
	is_locally_managed   CHAR(1)  NOT NULL ,
	is_virtual_device    CHAR(1)  NOT NULL ,
	date_in_service      timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device
	ADD CONSTRAINT "pk_device" PRIMARY KEY (device_id);

ALTER TABLE device
	ADD CONSTRAINT "ak_device_chassis_location_id" UNIQUE (chassis_location_id);

ALTER TABLE device
	ADD CONSTRAINT "ak_device_rack_location_id" UNIQUE (rack_location_id);

CREATE INDEX idx_device_type_location ON device
( 
	device_type_id
);

CREATE INDEX idx_dev_islclymgd ON device
( 
	is_locally_managed
);

CREATE INDEX idx_dev_is_virtual_dev ON device
( 
	is_virtual_device
);

CREATE INDEX idx_dev_name ON device
( 
	device_name
);

CREATE INDEX idx_dev_parent_device_id ON device
( 
	parent_device_id
);

CREATE INDEX idx_dev_phys_label ON device
( 
	physical_label
);

CREATE INDEX xif_chasloc_chass_devid ON device
( 
	chassis_location_id
);

CREATE INDEX xif_device_comp_id ON device
( 
	component_id
);

CREATE INDEX xif_device_dev_val_status ON device
( 
	device_status
);

CREATE INDEX xif_device_dev_v_svcenv ON device
( 
	service_environment_id
);

CREATE INDEX xif_device_id_dnsrecord ON device
( 
	identifying_dns_record_id
);

CREATE INDEX xif_device_site_code ON device
( 
	site_code
);

CREATE INDEX xif_dev_chass_loc_id_mod_enfc ON device
( 
	chassis_location_id,
	parent_device_id,
	device_type_id
);

CREATE INDEX xif_dev_devtp_id ON device
( 
	device_type_id
);

CREATE INDEX xif_dev_os_id ON device
( 
	operating_system_id
);

CREATE INDEX xif_dev_rack_location_id ON device
( 
	rack_location_id
);

/***********************************************
 * Table: device_collection
 ***********************************************/

CREATE TABLE device_collection
( 
	device_collection_id serial  NOT NULL ,
	device_collection_name varchar(255)  NOT NULL ,
	device_collection_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_collection
	ADD CONSTRAINT "pk_device_collection" PRIMARY KEY (device_collection_id);

ALTER TABLE device_collection
	ADD CONSTRAINT "ak_uq_devicecoll_name_type" UNIQUE (device_collection_name,device_collection_type);

CREATE INDEX idx_devcoll_devcolltype ON device_collection
( 
	device_collection_type
);

/***********************************************
 * Table: device_collection_assigned_certificate
 ***********************************************/

CREATE TABLE device_collection_assigned_certificate
( 
	device_collection_id integer  NOT NULL ,
	x509_signed_certificate_id integer  NOT NULL ,
	x509_key_usage       character varying(50)  NOT NULL ,
	x509_file_format     character varying(50)  NOT NULL ,
	file_location_path   varchar(255)  NOT NULL ,
	key_tool_label       varchar(255)  NULL ,
	file_access_mode     integer  NOT NULL ,
	file_owner_account_id integer  NOT NULL ,
	file_group_account_collection_id integer  NOT NULL ,
	file_passphrase_path varchar(255)  NULL ,
	key_usage_reason_for_assignment varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "pk_device_collection_assigned" PRIMARY KEY (device_collection_id,x509_signed_certificate_id,x509_key_usage);

/***********************************************
 * Table: device_collection_device
 ***********************************************/

CREATE TABLE device_collection_device
( 
	device_id            integer  NOT NULL ,
	device_collection_id integer  NOT NULL ,
	device_id_rank       integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_collection_device
	ADD CONSTRAINT "pk_device_collection_device" PRIMARY KEY (device_id,device_collection_id);

ALTER TABLE device_collection_device
	ADD CONSTRAINT "ak_dev_coll_dev_rank" UNIQUE (device_collection_id,device_id_rank);

CREATE INDEX ix_dev_col_dev_dev_colid ON device_collection_device
( 
	device_collection_id
);

/***********************************************
 * Table: device_collection_hier
 ***********************************************/

CREATE TABLE device_collection_hier
( 
	device_collection_id integer  NOT NULL ,
	child_device_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_collection_hier
	ADD CONSTRAINT "pk_device_collection_hier" PRIMARY KEY (device_collection_id,child_device_collection_id);

/***********************************************
 * Table: device_collection_ssh_key
 ***********************************************/

CREATE TABLE device_collection_ssh_key
( 
	ssh_key_id           integer  NOT NULL ,
	device_collection_id integer  NOT NULL ,
	account_collection_id integer  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT "pk_device_collection_ssh_key" PRIMARY KEY (ssh_key_id,device_collection_id,account_collection_id);

CREATE INDEX xif1device_collection_ssh_key ON device_collection_ssh_key
( 
	ssh_key_id
);

CREATE INDEX xif2device_collection_ssh_key ON device_collection_ssh_key
( 
	device_collection_id
);

CREATE INDEX xif3device_collection_ssh_key ON device_collection_ssh_key
( 
	account_collection_id
);

/***********************************************
 * Table: device_encapsulation_domain
 ***********************************************/

CREATE TABLE device_encapsulation_domain
( 
	device_id            integer  NOT NULL ,
	encapsulation_type   character varying(50)  NOT NULL ,
	encapsulation_domain character varying(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT "pk_device_encapsulation_domain" PRIMARY KEY (device_id,encapsulation_type);

CREATE INDEX xif_dev_encap_domain_devid ON device_encapsulation_domain
( 
	device_id
);

CREATE INDEX xif_dev_encap_domain_encaptyp ON device_encapsulation_domain
( 
	encapsulation_type
);

CREATE INDEX xif_dev_encap_domain_enc_domtyp ON device_encapsulation_domain
( 
	encapsulation_domain,
	encapsulation_type
);

/***********************************************
 * Table: device_layer2_network
 ***********************************************/

CREATE TABLE device_layer2_network
( 
	device_id            integer  NOT NULL ,
	layer2_network_id    integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_layer2_network
	ADD CONSTRAINT "pk_device_layer2_network" PRIMARY KEY (device_id,layer2_network_id);

CREATE INDEX xif_device_l2_net_devid ON device_layer2_network
( 
	device_id
);

CREATE INDEX xif_device_l2_net_l2netid ON device_layer2_network
( 
	layer2_network_id
);

/***********************************************
 * Table: device_management_controller
 ***********************************************/

CREATE TABLE device_management_controller
( 
	manager_device_id    integer  NOT NULL ,
	device_id            integer  NOT NULL ,
	device_management_control_type character varying(255)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_management_controller
	ADD CONSTRAINT "pk_device_management_controller" PRIMARY KEY (manager_device_id,device_id);

CREATE INDEX xif1device_management_controller ON device_management_controller
( 
	manager_device_id
);

CREATE INDEX xif2device_management_controller ON device_management_controller
( 
	device_id
);

CREATE INDEX xif3device_management_controller ON device_management_controller
( 
	device_management_control_type
);

/***********************************************
 * Table: device_note
 ***********************************************/

CREATE TABLE device_note
( 
	note_id              serial  NOT NULL ,
	device_id            integer  NOT NULL ,
	note_text            varchar(4000)  NOT NULL ,
	note_date            timestamp with time zone  NOT NULL ,
	note_user            varchar(30)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_note
	ADD CONSTRAINT "pk_device_note" PRIMARY KEY (note_id);

CREATE INDEX idx_devnote_devid ON device_note
( 
	device_id
);

/***********************************************
 * Table: device_ssh_key
 ***********************************************/

CREATE TABLE device_ssh_key
( 
	device_id            integer  NOT NULL ,
	ssh_key_id           integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_ssh_key
	ADD CONSTRAINT "pk_device_ssh_key" PRIMARY KEY (device_id,ssh_key_id);

CREATE INDEX xif1device_ssh_key ON device_ssh_key
( 
	ssh_key_id
);

CREATE INDEX xif2device_ssh_key ON device_ssh_key
( 
	device_id
);

/***********************************************
 * Table: device_ticket
 ***********************************************/

CREATE TABLE device_ticket
( 
	device_id            integer  NOT NULL ,
	ticketing_system_id  integer  NOT NULL ,
	ticket_number        varchar(30)  NOT NULL ,
	device_ticket_notes  varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_ticket
	ADD CONSTRAINT "pk_device_ticket" PRIMARY KEY (device_id,ticketing_system_id,ticket_number);

CREATE INDEX xifdev_tkt_dev_id ON device_ticket
( 
	device_id
);

CREATE INDEX xifdev_tkt_tkt_system ON device_ticket
( 
	ticketing_system_id
);

/***********************************************
 * Table: device_type
 ***********************************************/

CREATE TABLE device_type
( 
	device_type_id       serial  NOT NULL ,
	component_type_id    integer  NULL ,
	device_type_name     varchar(50)  NOT NULL ,
	template_device_id   integer  NULL ,
	idealized_device_id  integer  NULL ,
	description          varchar(4000)  NULL ,
	company_id           integer  NULL ,
	model                varchar(255)  NOT NULL ,
	device_type_depth_in_cm varchar(50)  NULL ,
	processor_architecture varchar(50)  NULL ,
	config_fetch_type    varchar(50)  NULL ,
	rack_units           integer  NULL ,
	has_802_3_interface  CHAR(1)  NOT NULL ,
	has_802_11_interface CHAR(1)  NOT NULL ,
	snmp_capable         CHAR(1)  NOT NULL ,
	is_chassis           char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_type
	ADD CONSTRAINT "pk_device_type" PRIMARY KEY (device_type_id);

CREATE INDEX xif4device_type ON device_type
( 
	company_id
);

CREATE INDEX xif_dev_typ_idealized_dev_id ON device_type
( 
	idealized_device_id
);

CREATE INDEX xif_dev_typ_tmplt_dev_typ_id ON device_type
( 
	template_device_id
);

CREATE INDEX xif_fevtyp_component_id ON device_type
( 
	component_type_id
);

/***********************************************
 * Table: device_type_module
 ***********************************************/

CREATE TABLE device_type_module
( 
	device_type_id       integer  NOT NULL ,
	device_type_module_name varchar(255)  NOT NULL ,
	description          varchar(255)  NULL ,
	device_type_x_offset varchar(50)  NULL ,
	device_type_y_offset varchar(50)  NULL ,
	device_type_z_offset varchar(50)  NULL ,
	device_type_side     varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_type_module
	ADD CONSTRAINT "pk_device_type_module" PRIMARY KEY (device_type_id,device_type_module_name);

CREATE INDEX xif1device_type_module ON device_type_module
( 
	device_type_id
);

/***********************************************
 * Table: device_type_module_device_type
 ***********************************************/

CREATE TABLE device_type_module_device_type
( 
	module_device_type_id integer  NOT NULL ,
	device_type_id       integer  NOT NULL ,
	device_type_module_name character varying(255)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT "pk_device_type_module_device_type" PRIMARY KEY (module_device_type_id,device_type_id,device_type_module_name);

CREATE INDEX xif_dt_mod_dev_type_dtmod ON device_type_module_device_type
( 
	device_type_id,
	device_type_module_name
);

CREATE INDEX xif_dt_mod_dev_type_mod_dtid ON device_type_module_device_type
( 
	module_device_type_id
);

/***********************************************
 * Table: dns_change_record
 ***********************************************/

CREATE TABLE dns_change_record
( 
	dns_change_record_id bigserial  NOT NULL ,
	dns_domain_id        integer  NULL ,
	ip_universe_id       integer  NULL ,
	ip_address           inet  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_change_record
	ADD CONSTRAINT "pk_dns_change_record" PRIMARY KEY (dns_change_record_id);

CREATE INDEX xif1dns_change_record ON dns_change_record
( 
	dns_domain_id
);

CREATE INDEX xif2dns_change_record ON dns_change_record
( 
	ip_universe_id
);

/***********************************************
 * Table: dns_domain
 ***********************************************/

CREATE TABLE dns_domain
( 
	dns_domain_id        serial  NOT NULL ,
	soa_name             varchar(255)  NOT NULL ,
	dns_domain_name      varchar(255)  NOT NULL ,
	dns_domain_type      varchar(50)  NOT NULL ,
	parent_dns_domain_id integer  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_domain
	ADD CONSTRAINT "pk_dns_domain" PRIMARY KEY (dns_domain_id);

ALTER TABLE dns_domain
	ADD CONSTRAINT "ak_dns_domain_name_type" UNIQUE (dns_domain_name,dns_domain_type);

CREATE INDEX idx_dnsdomain_parentdnsdomain ON dns_domain
( 
	parent_dns_domain_id
);

CREATE INDEX xifdns_dom_dns_dom_type ON dns_domain
( 
	dns_domain_type
);

/***********************************************
 * Table: dns_domain_collection
 ***********************************************/

CREATE TABLE dns_domain_collection
( 
	dns_domain_collection_id serial  NOT NULL ,
	dns_domain_collection_name varchar(50)  NOT NULL ,
	dns_domain_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_domain_collection
	ADD CONSTRAINT "pk_dns_domain_collection" PRIMARY KEY (dns_domain_collection_id);

ALTER TABLE dns_domain_collection
	ADD CONSTRAINT "ak_dns_domain_collection_namtyp" UNIQUE (dns_domain_collection_name,dns_domain_collection_type);

CREATE INDEX xif1dns_domain_collection ON dns_domain_collection
( 
	dns_domain_collection_type
);

/***********************************************
 * Table: dns_domain_collection_dns_domain
 ***********************************************/

CREATE TABLE dns_domain_collection_dns_domain
( 
	dns_domain_collection_id integer  NOT NULL ,
	dns_domain_id        integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_domain_collection_dns_domain
	ADD CONSTRAINT "pk_dns_domain_collection_dns_dom" PRIMARY KEY (dns_domain_collection_id,dns_domain_id);

CREATE INDEX xif1dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain
( 
	dns_domain_id
);

CREATE INDEX xif2dns_domain_collection_dns_domain ON dns_domain_collection_dns_domain
( 
	dns_domain_collection_id
);

/***********************************************
 * Table: dns_domain_collection_hier
 ***********************************************/

CREATE TABLE dns_domain_collection_hier
( 
	dns_domain_collection_id integer  NOT NULL ,
	child_dns_domain_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT "pk_dns_domain_collection_hier" PRIMARY KEY (dns_domain_collection_id,child_dns_domain_collection_id);

CREATE INDEX xif1dns_domain_collection_hier ON dns_domain_collection_hier
( 
	child_dns_domain_collection_id
);

CREATE INDEX xif2dns_domain_collection_hier ON dns_domain_collection_hier
( 
	dns_domain_collection_id
);

/***********************************************
 * Table: dns_domain_ip_universe
 ***********************************************/

CREATE TABLE dns_domain_ip_universe
( 
	dns_domain_id        integer  NOT NULL ,
	ip_universe_id       integer  NOT NULL ,
	soa_class            varchar(50)  NULL ,
	soa_ttl              integer  NULL ,
	soa_serial           integer  NULL ,
	soa_refresh          integer  NULL ,
	soa_retry            integer  NULL ,
	soa_expire           integer  NULL ,
	soa_minimum          integer  NULL ,
	soa_mname            varchar(255)  NULL ,
	soa_rname            varchar(255)  NOT NULL ,
	should_generate      CHAR(1)  NOT NULL ,
	last_generated       timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT "pk_dns_domain_ip_universe" PRIMARY KEY (dns_domain_id,ip_universe_id);

CREATE INDEX xifdnsdom_ipu_dnsdomid ON dns_domain_ip_universe
( 
	dns_domain_id
);

CREATE INDEX xifdnsdom_ipu_ipu ON dns_domain_ip_universe
( 
	ip_universe_id
);

/***********************************************
 * Table: dns_record
 ***********************************************/

CREATE TABLE dns_record
( 
	dns_record_id        serial  NOT NULL ,
	dns_name             varchar(255)  NULL ,
	dns_domain_id        integer  NOT NULL ,
	dns_ttl              integer  NULL ,
	dns_class            varchar(50)  NOT NULL ,
	dns_type             character varying(50)  NOT NULL ,
	dns_value            varchar(512)  NULL ,
	dns_priority         integer  NULL ,
	dns_srv_service      character varying(50)  NULL ,
	dns_srv_protocol     varchar(4)  NULL ,
	dns_srv_weight       integer  NULL ,
	dns_srv_port         integer  NULL ,
	netblock_id          integer  NULL ,
	ip_universe_id       integer  NOT NULL ,
	reference_dns_record_id integer  NULL ,
	dns_value_record_id  integer  NULL ,
	should_generate_ptr  CHAR(1)  NOT NULL ,
	is_enabled           CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_record
	ADD CONSTRAINT "pk_dns_record" PRIMARY KEY (dns_record_id);

ALTER TABLE dns_record
	ADD CONSTRAINT "ak_dns_record_dnsrec_domainid" UNIQUE (dns_record_id,dns_domain_id);

CREATE INDEX idx_dnsrec_dnsclass ON dns_record
( 
	dns_class
);

CREATE INDEX idx_dnsrec_dnssrvservice ON dns_record
( 
	dns_srv_service
);

CREATE INDEX xif_dnsid_dnsdom_id ON dns_record
( 
	dns_domain_id
);

CREATE INDEX xif_dnsid_nblk_id ON dns_record
( 
	netblock_id
);

CREATE INDEX xif_dnsrecord_vdnstype ON dns_record
( 
	dns_type
);

CREATE INDEX xif_dns_rec_ip_universe ON dns_record
( 
	ip_universe_id
);

CREATE INDEX xif_ref_dnsrec_dnserc ON dns_record
( 
	reference_dns_record_id,
	dns_domain_id
);

/***********************************************
 * Table: dns_record_relation
 ***********************************************/

CREATE TABLE dns_record_relation
( 
	dns_record_id        integer  NOT NULL ,
	related_dns_record_id integer  NOT NULL ,
	dns_record_relation_type varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE dns_record_relation
	ADD CONSTRAINT "pk_dns_record_relation" PRIMARY KEY (dns_record_id,related_dns_record_id,dns_record_relation_type);

/***********************************************
 * Table: encapsulation_domain
 ***********************************************/

CREATE TABLE encapsulation_domain
( 
	encapsulation_domain varchar(50)  NOT NULL ,
	encapsulation_type   character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE encapsulation_domain
	ADD CONSTRAINT "pk_encapsulation_domain" PRIMARY KEY (encapsulation_domain,encapsulation_type);

CREATE INDEX xif_encap_domain_encap_typ ON encapsulation_domain
( 
	encapsulation_type
);

/***********************************************
 * Table: encapsulation_range
 ***********************************************/

CREATE TABLE encapsulation_range
( 
	encapsulation_range_id serial  NOT NULL ,
	parent_encapsulation_range_id integer  NULL ,
	site_code            character varying(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE encapsulation_range
	ADD CONSTRAINT "pk_vlan_range" PRIMARY KEY (encapsulation_range_id);

CREATE INDEX ixf_encap_range_parentvlan ON encapsulation_range
( 
	parent_encapsulation_range_id
);

CREATE INDEX ixf_encap_range_sitecode ON encapsulation_range
( 
	site_code
);

/***********************************************
 * Table: encryption_key
 ***********************************************/

CREATE TABLE encryption_key
( 
	encryption_key_id    serial  NOT NULL ,
	encryption_key_db_value varchar(255)  NOT NULL ,
	encryption_key_purpose varchar(50)  NOT NULL ,
	encryption_key_purpose_version integer  NOT NULL ,
	encryption_method    character varying(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE encryption_key
	ADD CONSTRAINT "pk_encryption_key" PRIMARY KEY (encryption_key_id);

/***********************************************
 * Table: inter_component_connection
 ***********************************************/

CREATE TABLE inter_component_connection
( 
	inter_component_connection_id serial  NOT NULL ,
	slot1_id             integer  NOT NULL ,
	slot2_id             integer  NOT NULL ,
	circuit_id           integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE inter_component_connection
	ADD CONSTRAINT "pk_inter_component_connection" PRIMARY KEY (inter_component_connection_id);

ALTER TABLE inter_component_connection
	ADD CONSTRAINT "ak_inter_component_con_sl1_id" UNIQUE (slot1_id);

ALTER TABLE inter_component_connection
	ADD CONSTRAINT "ak_inter_component_con_sl2_id" UNIQUE (slot2_id);

CREATE INDEX xif_intercomp_conn_slot1_id ON inter_component_connection
( 
	slot1_id
);

CREATE INDEX xif_intercomp_conn_slot2_id ON inter_component_connection
( 
	slot2_id
);

CREATE INDEX xif_intercom_conn_circ_id ON inter_component_connection
( 
	circuit_id
);

/***********************************************
 * Table: ip_universe
 ***********************************************/

CREATE TABLE ip_universe
( 
	ip_universe_id       serial  NOT NULL ,
	ip_universe_name     varchar(50)  NOT NULL ,
	ip_namespace         varchar(50)  NOT NULL ,
	should_generate_dns  char(1)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE ip_universe
	ADD CONSTRAINT "pk_ip_universe" PRIMARY KEY (ip_universe_id);

ALTER TABLE ip_universe
	ADD CONSTRAINT "ak_ip_universe_name" UNIQUE (ip_universe_name);

CREATE INDEX xif1ip_universe ON ip_universe
( 
	ip_namespace
);

/***********************************************
 * Table: ip_universe_visibility
 ***********************************************/

CREATE TABLE ip_universe_visibility
( 
	ip_universe_id       integer  NOT NULL ,
	visible_ip_universe_id integer  NOT NULL ,
	propagate_dns        char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT "pk_ip_universe_visibility" PRIMARY KEY (ip_universe_id,visible_ip_universe_id);

CREATE INDEX xifip_universe_vis_ip_univ ON ip_universe_visibility
( 
	ip_universe_id
);

CREATE INDEX xifip_universe_vis_ip_univ_vis ON ip_universe_visibility
( 
	visible_ip_universe_id
);

/***********************************************
 * Table: kerberos_realm
 ***********************************************/

CREATE TABLE kerberos_realm
( 
	krb_realm_id         serial  NOT NULL ,
	realm_name           varchar(100)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE kerberos_realm
	ADD CONSTRAINT "pk_kerberos_realms" PRIMARY KEY (krb_realm_id);

CREATE INDEX idx_realm_name ON kerberos_realm
( 
	realm_name
);

/***********************************************
 * Table: klogin
 ***********************************************/

CREATE TABLE klogin
( 
	klogin_id            serial  NOT NULL ,
	account_id           integer  NOT NULL ,
	account_collection_id integer  NULL ,
	krb_realm_id         integer  NOT NULL ,
	krb_instance         varchar(50)  NULL ,
	destination_account_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE klogin
	ADD CONSTRAINT "pk_klogin_id" PRIMARY KEY (klogin_id);

CREATE INDEX idx_klogin_acctid ON klogin
( 
	account_id
);

CREATE INDEX idx_klogin_destacctid ON klogin
( 
	destination_account_id
);

CREATE INDEX idx_klogin_krbrealmid ON klogin
( 
	krb_realm_id
);

/***********************************************
 * Table: klogin_mclass
 ***********************************************/

CREATE TABLE klogin_mclass
( 
	klogin_id            integer  NOT NULL ,
	device_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE klogin_mclass
	ADD CONSTRAINT "pk_klogin_mclass" PRIMARY KEY (klogin_id,device_collection_id);

/***********************************************
 * Table: layer2_connection
 ***********************************************/

CREATE TABLE layer2_connection
( 
	layer2_connection_id serial  NOT NULL ,
	logical_port1_id     integer  NULL ,
	logical_port2_id     integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer2_connection
	ADD CONSTRAINT "pk_layer2_connection" PRIMARY KEY (layer2_connection_id);

CREATE INDEX xif_l2_conn_l1port ON layer2_connection
( 
	logical_port1_id
);

CREATE INDEX xif_l2_conn_l2port ON layer2_connection
( 
	logical_port2_id
);

/***********************************************
 * Table: layer2_connection_layer2_network
 ***********************************************/

CREATE TABLE layer2_connection_layer2_network
( 
	layer2_connection_id integer  NOT NULL ,
	layer2_network_id    integer  NOT NULL ,
	encapsulation_mode   varchar(50)  NULL ,
	encapsulation_type   character varying(50)  NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer2_connection_layer2_network
	ADD CONSTRAINT "pk_val_layer2_encapsulation_type" PRIMARY KEY (layer2_connection_id,layer2_network_id);

CREATE INDEX xif_l2cl2n_l2net_id_encap_typ ON layer2_connection_layer2_network
( 
	layer2_network_id,
	encapsulation_type
);

CREATE INDEX xif_l2c_l2n_encap_mode_type ON layer2_connection_layer2_network
( 
	encapsulation_mode,
	encapsulation_type
);

CREATE INDEX xif_l2c_l2n_l2connid ON layer2_connection_layer2_network
( 
	layer2_connection_id
);

CREATE INDEX xif_l2c_l2n_l2netid ON layer2_connection_layer2_network
( 
	layer2_network_id
);

/***********************************************
 * Table: layer2_network
 ***********************************************/

CREATE TABLE layer2_network
( 
	layer2_network_id    serial  NOT NULL ,
	encapsulation_name   varchar(32)  NULL ,
	encapsulation_domain character varying(50)  NULL ,
	encapsulation_type   varchar(50)  NULL ,
	encapsulation_tag    integer  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	encapsulation_range_id integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer2_network
	ADD CONSTRAINT "pk_layer2_network" PRIMARY KEY (layer2_network_id);

ALTER TABLE layer2_network
	ADD CONSTRAINT "ak_l2net_encap_name" UNIQUE (encapsulation_domain,encapsulation_type,encapsulation_name);

ALTER TABLE layer2_network
	ADD CONSTRAINT "ak_l2net_encap_tag" UNIQUE (encapsulation_type,encapsulation_domain,encapsulation_tag);

ALTER TABLE layer2_network
	ADD CONSTRAINT "ak_l2_net_l2net_encap_typ" UNIQUE (layer2_network_id,encapsulation_type);

CREATE INDEX xif_l2_net_encap_domain ON layer2_network
( 
	encapsulation_domain,
	encapsulation_type
);

CREATE INDEX xif_l2_net_encap_range_id ON layer2_network
( 
	encapsulation_range_id
);

/***********************************************
 * Table: layer2_network_collection
 ***********************************************/

CREATE TABLE layer2_network_collection
( 
	layer2_network_collection_id serial  NOT NULL ,
	layer2_network_collection_name varchar(255)  NOT NULL ,
	layer2_network_collection_type varchar(50)  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer2_network_collection
	ADD CONSTRAINT "pk_layer2_network_collection" PRIMARY KEY (layer2_network_collection_id);

ALTER TABLE layer2_network_collection
	ADD CONSTRAINT "ak_l2network_coll_name_type" UNIQUE (layer2_network_collection_name,layer2_network_collection_type);

CREATE INDEX xif_l2netcoll_type ON layer2_network_collection
( 
	layer2_network_collection_type
);

/***********************************************
 * Table: layer2_network_collection_hier
 ***********************************************/

CREATE TABLE layer2_network_collection_hier
( 
	layer2_network_collection_id integer  NOT NULL ,
	child_layer2_network_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT "pk_layer2_network_collection_hier" PRIMARY KEY (layer2_network_collection_id,child_layer2_network_collection_id);

CREATE INDEX xif_l2net_collhier_chldl2net ON layer2_network_collection_hier
( 
	child_layer2_network_collection_id
);

CREATE INDEX xif_l2net_collhier_l2net ON layer2_network_collection_hier
( 
	layer2_network_collection_id
);

CREATE TABLE layer2_network_collection_layer2_network
( 
	layer2_network_collection_id integer  NOT NULL ,
	layer2_network_id    integer  NOT NULL ,
	layer2_network_id_rank integer  NULL ,
	start_date           timestamp without time zone  NULL ,
	finish_date          timestamp without time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer2_network_collection_layer2_network
	ADD CONSTRAINT "pk_l2_network_coll_l2_network" PRIMARY KEY (layer2_network_collection_id,layer2_network_id);

ALTER TABLE layer2_network_collection_layer2_network
	ADD CONSTRAINT "xak_l2netcol_l2netrank" UNIQUE (layer2_network_collection_id,layer2_network_id_rank);

CREATE INDEX xif_l2netcl2net_collid ON layer2_network_collection_layer2_network
( 
	layer2_network_collection_id
);

CREATE INDEX xif_l2netcl2net_l2netid ON layer2_network_collection_layer2_network
( 
	layer2_network_id
);

/***********************************************
 * Table: layer3_interface
 ***********************************************/

CREATE TABLE layer3_interface
( 
	layer3_interface_id  serial  NOT NULL ,
	layer3_interface_name varchar(255)  NULL ,
	layer3_interface_type character varying(50)  NOT NULL ,
	device_id            integer  NOT NULL ,
	description          varchar(255)  NULL ,
	parent_layer3_interface_id integer  NULL ,
	parent_relation_type varchar(255)  NULL ,
	slot_id              integer  NULL ,
	logical_port_id      integer  NULL ,
	is_interface_up      CHAR(1)  NOT NULL ,
	mac_addr             macaddr  NULL ,
	should_monitor       CHAR(1)  NOT NULL ,
	should_manage        CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_interface
	ADD CONSTRAINT "pk_network_interface_id" PRIMARY KEY (layer3_interface_id);

ALTER TABLE layer3_interface
	ADD CONSTRAINT "ak_net_int_devid_netintid" UNIQUE (layer3_interface_id,device_id);

ALTER TABLE layer3_interface
	ADD CONSTRAINT "uq_netint_device_id_logical_port_id" UNIQUE (device_id,logical_port_id);

ALTER TABLE layer3_interface
	ADD CONSTRAINT "fk_netint_devid_name" UNIQUE (device_id,layer3_interface_name);

CREATE INDEX xif12layer3_interface ON layer3_interface
( 
	logical_port_id,
	device_id
);

CREATE INDEX idx_netint_isifaceup ON layer3_interface
( 
	is_interface_up
);

CREATE INDEX idx_netint_shouldmange ON layer3_interface
( 
	should_manage
);

CREATE INDEX idx_netint_shouldmonitor ON layer3_interface
( 
	should_monitor
);

CREATE INDEX xif_netint_netdev_id ON layer3_interface
( 
	device_id
);

CREATE INDEX xif_netint_parentnetint ON layer3_interface
( 
	parent_layer3_interface_id
);

CREATE INDEX xif_netint_slot_id ON layer3_interface
( 
	slot_id 
);

CREATE INDEX xif_netint_typeid ON layer3_interface
( 
	layer3_interface_type
);

/***********************************************
 * Table: layer3_interface_netblock
 ***********************************************/

CREATE TABLE layer3_interface_netblock
( 
	netblock_id          integer  NOT NULL ,
	layer3_interface_id  integer  NOT NULL ,
	device_id            integer  NOT NULL ,
	network_interface_rank integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_interface_netblock
	ADD CONSTRAINT "pk_network_interface_netblock" PRIMARY KEY (netblock_id,layer3_interface_id,device_id);

ALTER TABLE layer3_interface_netblock
	ADD CONSTRAINT "ak_netint_nblk_nblk_id" UNIQUE (netblock_id);

ALTER TABLE layer3_interface_netblock
	ADD CONSTRAINT "ak_network_interface_nblk_ni_rank" UNIQUE (layer3_interface_id,network_interface_rank);

CREATE INDEX xif_netint_nb_nblk_id ON layer3_interface_netblock
( 
	layer3_interface_id,
	device_id
);

CREATE UNIQUE INDEX xif_netint_nb_netint_id ON layer3_interface_netblock
( 
	netblock_id
);

/***********************************************
 * Table: layer3_interface_purpose
 ***********************************************/

CREATE TABLE layer3_interface_purpose
( 
	device_id            integer  NOT NULL ,
	network_interface_purpose character varying(50)  NOT NULL ,
	layer3_interface_id  integer  NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_interface_purpose
	ADD CONSTRAINT "pk_network_int_purpose" PRIMARY KEY (device_id,network_interface_purpose);

CREATE INDEX xifnetint_purpose_device_id ON layer3_interface_purpose
( 
	device_id
);

CREATE INDEX xifnetint_purpose_val_netint_p ON layer3_interface_purpose
( 
	network_interface_purpose
);

CREATE INDEX xifnetint_purp_dev_ni_id ON layer3_interface_purpose
( 
	layer3_interface_id,
	device_id
);

/***********************************************
 * Table: layer3_network
 ***********************************************/

CREATE TABLE layer3_network
( 
	layer3_network_id    serial  NOT NULL ,
	netblock_id          integer  NOT NULL ,
	layer2_network_id    integer  NULL ,
	default_gateway_netblock_id integer  NULL ,
	rendezvous_netblock_id integer  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_network
	ADD CONSTRAINT "pk_layer3_network" PRIMARY KEY (layer3_network_id);

ALTER TABLE layer3_network
	ADD CONSTRAINT "ak_layer3_network_netblock_id" UNIQUE (netblock_id)
	DEFERRABLE  ;

CREATE INDEX xif_l3net_l2net ON layer3_network
( 
	layer2_network_id
);

CREATE INDEX xif_l3net_rndv_pt_nblk_id ON layer3_network
( 
	rendezvous_netblock_id
);

CREATE INDEX xif_l3_net_def_gate_nbid ON layer3_network
( 
	default_gateway_netblock_id
);

CREATE INDEX xif_layer3_network_netblock_id ON layer3_network
( 
	netblock_id
);

/***********************************************
 * Table: layer3_network_collection
 ***********************************************/

CREATE TABLE layer3_network_collection
( 
	layer3_network_collection_id serial  NOT NULL ,
	layer3_network_collection_name varchar(255)  NOT NULL ,
	layer3_network_collection_type varchar(50)  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_network_collection
	ADD CONSTRAINT "pk_layer3_network_collection" PRIMARY KEY (layer3_network_collection_id);

ALTER TABLE layer3_network_collection
	ADD CONSTRAINT "ak_l3netcoll_name_type" UNIQUE (layer3_network_collection_name,layer3_network_collection_type);

CREATE INDEX xif_l3_netcol_netcol_type ON layer3_network_collection
( 
	layer3_network_collection_type
);

/***********************************************
 * Table: layer3_network_collection_hier
 ***********************************************/

CREATE TABLE layer3_network_collection_hier
( 
	layer3_network_collection_id integer  NOT NULL ,
	child_layer3_network_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT "pk_layer3_network_collection_hier" PRIMARY KEY (layer3_network_collection_id,child_layer3_network_collection_id);

CREATE INDEX xif_l3nethierl3netid ON layer3_network_collection_hier
( 
	layer3_network_collection_id
);

CREATE INDEX xif_l3nethier_chld_l3netid ON layer3_network_collection_hier
( 
	child_layer3_network_collection_id
);

CREATE TABLE layer3_network_collection_layer3_network
( 
	layer3_network_collection_id integer  NOT NULL ,
	layer3_network_id    integer  NOT NULL ,
	layer3_network_id_rank integer  NULL ,
	start_date           timestamp without time zone  NULL ,
	finish_date          timestamp without time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE layer3_network_collection_layer3_network
	ADD CONSTRAINT "pk_l3_network_coll_l3_network" PRIMARY KEY (layer3_network_collection_id,layer3_network_id);

ALTER TABLE layer3_network_collection_layer3_network
	ADD CONSTRAINT "ak_l3netcol_l3netrank" UNIQUE (layer3_network_collection_id,layer3_network_id_rank);

CREATE INDEX xif_l3netcol_l3_net_l3netcolid ON layer3_network_collection_layer3_network
( 
	layer3_network_collection_id
);

CREATE INDEX xif_l3netcol_l3_net_l3netid ON layer3_network_collection_layer3_network
( 
	layer3_network_id
);

/***********************************************
 * Table: logical_port
 ***********************************************/

CREATE TABLE logical_port
( 
	logical_port_id      serial  NOT NULL ,
	logical_port_name    varchar(50)  NOT NULL ,
	logical_port_type    character varying(50)  NOT NULL ,
	device_id            integer  NULL ,
	mlag_peering_id      integer  NULL ,
	parent_logical_port_id integer  NULL ,
	mac_address          macaddr  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE logical_port
	ADD CONSTRAINT "pk_logical_port" PRIMARY KEY (logical_port_id);

ALTER TABLE logical_port
	ADD CONSTRAINT "uq_device_id_logical_port_id" UNIQUE (logical_port_id,device_id);

ALTER TABLE logical_port
	ADD CONSTRAINT "uq_lg_port_name_type_device" UNIQUE (logical_port_name,logical_port_type,device_id);

ALTER TABLE logical_port
	ADD CONSTRAINT "uq_lg_port_name_type_mlag" UNIQUE (logical_port_name,logical_port_type,mlag_peering_id);

CREATE INDEX xif3logical_port ON logical_port
( 
	device_id
);

CREATE INDEX xif4logical_port ON logical_port
( 
	mlag_peering_id
);

CREATE INDEX xif_logical_port_lg_port_type ON logical_port
( 
	logical_port_type
);

CREATE INDEX xif_logical_port_parnet_id ON logical_port
( 
	parent_logical_port_id
);

/***********************************************
 * Table: logical_port_slot
 ***********************************************/

CREATE TABLE logical_port_slot
( 
	logical_port_id      integer  NOT NULL ,
	slot_id              integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE logical_port_slot
	ADD CONSTRAINT "pk_logical_port_slot" PRIMARY KEY (logical_port_id,slot_id);

CREATE INDEX xif_lgl_port_slot_lgl_port_id ON logical_port_slot
( 
	logical_port_id
);

CREATE INDEX xif_lgl_port_slot_slot_id ON logical_port_slot
( 
	slot_id 
);

/***********************************************
 * Table: logical_volume
 ***********************************************/

CREATE TABLE logical_volume
( 
	logical_volume_id    serial  NOT NULL ,
	logical_volume_name  varchar(50)  NOT NULL ,
	logical_volume_type  varchar(50)  NOT NULL ,
	volume_group_id      integer  NOT NULL ,
	device_id            integer  NOT NULL ,
	logical_volume_size_in_bytes bigint  NOT NULL ,
	logical_volume_offset_in_bytes bigint  NULL ,
	filesystem_type      varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE logical_volume
	ADD CONSTRAINT "pk_logical_volume" PRIMARY KEY (logical_volume_id);

ALTER TABLE logical_volume
	ADD CONSTRAINT "ak_logical_volume_filesystem" UNIQUE (logical_volume_id,filesystem_type);

ALTER TABLE logical_volume
	ADD CONSTRAINT "ak_logvol_devid_lvname" UNIQUE (device_id,logical_volume_name,logical_volume_type);

ALTER TABLE logical_volume
	ADD CONSTRAINT "ak_logvol_lv_devid" UNIQUE (logical_volume_id);

CREATE INDEX xif5logical_volume ON logical_volume
( 
	logical_volume_type
);

CREATE INDEX xif_logvol_device_id ON logical_volume
( 
	device_id
);

CREATE INDEX xif_logvol_fstype ON logical_volume
( 
	filesystem_type
);

CREATE INDEX xif_logvol_vgid ON logical_volume
( 
	volume_group_id,
	device_id
);

/***********************************************
 * Table: logical_volume_property
 ***********************************************/

CREATE TABLE logical_volume_property
( 
	logical_volume_property_id serial  NOT NULL ,
	logical_volume_id    integer  NULL ,
	logical_volume_type  varchar(50)  NULL ,
	logical_volume_purpose varchar(50)  NULL ,
	filesystem_type      character varying(50)  NULL ,
	logical_volume_property_name varchar(50)  NULL ,
	logical_volume_property_value varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE logical_volume_property
	ADD CONSTRAINT "pk_logical_volume_property" PRIMARY KEY (logical_volume_property_id);

ALTER TABLE logical_volume_property
	ADD CONSTRAINT "ak_logical_vol_prop_fs_lv_name" UNIQUE (logical_volume_id,logical_volume_property_name);

CREATE INDEX xif_lvol_prop_lvid_fstyp ON logical_volume_property
( 
	logical_volume_id,
	filesystem_type
);

CREATE INDEX xif_lvol_prop_lvpn_fsty ON logical_volume_property
( 
	logical_volume_property_name,
	filesystem_type
);

CREATE INDEX xif_lvprop_purpose ON logical_volume_property
( 
	logical_volume_purpose
);

CREATE INDEX xif_lvprop_type ON logical_volume_property
( 
	logical_volume_type
);

/***********************************************
 * Table: logical_volume_purpose
 ***********************************************/

CREATE TABLE logical_volume_purpose
( 
	logical_volume_purpose character varying(50)  NOT NULL ,
	logical_volume_id    integer  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE logical_volume_purpose
	ADD CONSTRAINT "pk_logical_volume_purpose" PRIMARY KEY (logical_volume_purpose,logical_volume_id);

CREATE INDEX xif_lvpurp_lvid ON logical_volume_purpose
( 
	logical_volume_id
);

CREATE INDEX xif_lvpurp_val_lgpuprp ON logical_volume_purpose
( 
	logical_volume_purpose
);

/***********************************************
 * Table: mlag_peering
 ***********************************************/

CREATE TABLE mlag_peering
( 
	mlag_peering_id      serial  NOT NULL ,
	device1_id           integer  NOT NULL ,
	device2_id           integer  NOT NULL ,
	domain_id            varchar(50)  NULL ,
	system_id            macaddr  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE mlag_peering
	ADD CONSTRAINT "pk_mlag_peering" PRIMARY KEY (mlag_peering_id);

CREATE INDEX xif_mlag_peering_devid1 ON mlag_peering
( 
	device1_id
);

CREATE INDEX xif_mlag_peering_devid2 ON mlag_peering
( 
	device2_id
);

/***********************************************
 * Table: netblock
 ***********************************************/

CREATE TABLE netblock
( 
	netblock_id          serial  NOT NULL ,
	ip_address           inet  NOT NULL ,
	netblock_type        varchar(50)  NOT NULL ,
	is_single_address    CHAR(1)  NOT NULL ,
	can_subnet           char(1)  NOT NULL ,
	parent_netblock_id   integer  NULL ,
	netblock_status      varchar(50)  NOT NULL ,
	ip_universe_id       integer  NOT NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE netblock
	ADD CONSTRAINT "pk_netblock" PRIMARY KEY (netblock_id);

ALTER TABLE netblock
	ADD CONSTRAINT "ak_netblock_params" UNIQUE (ip_address,netblock_type,ip_universe_id,is_single_address);

CREATE INDEX xif6netblock ON netblock
( 
	ip_universe_id
);

CREATE INDEX xif7netblock ON netblock
( 
	netblock_type
);

CREATE INDEX idx_netblk_netblkstatus ON netblock
( 
	netblock_status
);

CREATE INDEX ix_netblk_ip_address ON netblock
( 
	ip_address
);

CREATE INDEX ix_netblk_ip_address_parent ON netblock
( 
	parent_netblock_id
);

/***********************************************
 * Table: netblock_collection
 ***********************************************/

CREATE TABLE netblock_collection
( 
	netblock_collection_id serial  NOT NULL ,
	netblock_collection_name varchar(255)  NOT NULL ,
	netblock_collection_type varchar(50)  NULL ,
	netblock_ip_family_restriction integer  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE netblock_collection
	ADD CONSTRAINT "pk_netblock_collection" PRIMARY KEY (netblock_collection_id);

ALTER TABLE netblock_collection
	ADD CONSTRAINT "uq_netblock_collection_name" UNIQUE (netblock_collection_name,netblock_collection_type);

CREATE INDEX xifk_nb_col_val_nb_col_typ ON netblock_collection
( 
	netblock_collection_type
);

/***********************************************
 * Table: netblock_collection_hier
 ***********************************************/

CREATE TABLE netblock_collection_hier
( 
	netblock_collection_id integer  NOT NULL ,
	child_netblock_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT "pk_netblock_collection_hier" PRIMARY KEY (netblock_collection_id,child_netblock_collection_id);

CREATE INDEX xifk_nblk_c_hier_chld_nc ON netblock_collection_hier
( 
	child_netblock_collection_id
);

CREATE INDEX xifk_nblk_c_hier_prnt_nc ON netblock_collection_hier
( 
	netblock_collection_id
);

CREATE TABLE netblock_collection_netblock
( 
	netblock_collection_id integer  NOT NULL ,
	netblock_id          integer  NOT NULL ,
	netblock_id_rank     integer  NULL ,
	start_date           timestamp without time zone  NULL ,
	finish_date          timestamp without time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT "pk_netblock_collection_netblock" PRIMARY KEY (netblock_collection_id,netblock_id);

ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT "ak_netblk_coll_nblk_id" UNIQUE (netblock_collection_id,netblock_id_rank);

CREATE INDEX ifk_nb_col_nb_nblkid ON netblock_collection_netblock
( 
	netblock_id
);

CREATE INDEX xifk_nb_col_nb_nbcolid ON netblock_collection_netblock
( 
	netblock_collection_id
);

/***********************************************
 * Table: network_range
 ***********************************************/

CREATE TABLE network_range
( 
	network_range_id     serial  NOT NULL ,
	network_range_type   varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	parent_netblock_id   integer  NOT NULL ,
	start_netblock_id    integer  NOT NULL ,
	stop_netblock_id     integer  NOT NULL ,
	dns_prefix           varchar(255)  NULL ,
	dns_domain_id        integer  NULL ,
	lease_time           integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE network_range
	ADD CONSTRAINT "pk_network_range" PRIMARY KEY (network_range_id);

CREATE INDEX xif_netrng_dnsdomainid ON network_range
( 
	dns_domain_id
);

CREATE INDEX xif_netrng_netrng_typ ON network_range
( 
	network_range_type
);

CREATE INDEX xif_netrng_prngnblkid ON network_range
( 
	parent_netblock_id
);

CREATE INDEX xif_netrng_startnetblk ON network_range
( 
	start_netblock_id
);

CREATE INDEX xif_netrng_stopnetblk ON network_range
( 
	stop_netblock_id
);

/***********************************************
 * Table: network_service
 ***********************************************/

CREATE TABLE network_service
( 
	network_service_id   serial  NOT NULL ,
	name                 varchar(255)  NULL ,
	description          varchar(255)  NULL ,
	network_service_type character varying(50)  NOT NULL ,
	is_monitored         CHAR(1)  NOT NULL ,
	device_id            integer  NULL ,
	network_interface_id integer  NULL ,
	dns_record_id        integer  NULL ,
	service_environment_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE network_service
	ADD CONSTRAINT "pk_service" PRIMARY KEY (network_service_id);

CREATE INDEX idx_netsvc_ismonitored ON network_service
( 
	is_monitored
);

CREATE INDEX idx_netsvc_netsvctype ON network_service
( 
	network_service_type
);

CREATE INDEX idx_netsvc_svcenv ON network_service
( 
	service_environment_id
);

CREATE INDEX ix_netsvc_dnsidrecid ON network_service
( 
	dns_record_id
);

CREATE INDEX ix_netsvc_netdevid ON network_service
( 
	device_id
);

CREATE INDEX ix_netsvc_netintid ON network_service
( 
	network_interface_id
);

/***********************************************
 * Table: operating_system
 ***********************************************/

CREATE TABLE operating_system
( 
	operating_system_id  serial  NOT NULL ,
	operating_system_name varchar(255)  NOT NULL ,
	operating_system_short_name varchar(255)  NULL ,
	company_id           integer  NULL ,
	major_version        varchar(50)  NOT NULL ,
	version              varchar(255)  NOT NULL ,
	operating_system_family varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE operating_system
	ADD CONSTRAINT "pk_operating_system" PRIMARY KEY (operating_system_id);

ALTER TABLE operating_system
	ADD CONSTRAINT "ak_operating_system_name_version" UNIQUE (operating_system_name,version);

ALTER TABLE operating_system
	ADD CONSTRAINT "uq_operating_system_short_name" UNIQUE (operating_system_short_name);

CREATE INDEX xif_os_company ON operating_system
( 
	company_id
);

CREATE INDEX xif_os_os_family ON operating_system
( 
	operating_system_family
);

/***********************************************
 * Table: operating_system_snapshot
 ***********************************************/

CREATE TABLE operating_system_snapshot
( 
	operating_system_snapshot_id serial  NOT NULL ,
	operating_system_snapshot_name varchar(255)  NOT NULL ,
	operating_system_snapshot_type varchar(50)  NOT NULL ,
	operating_system_id  integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT "pk_val_operating_system_snapshot" PRIMARY KEY (operating_system_snapshot_id);

ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT "ak_os_snap_name_type" UNIQUE (operating_system_id,operating_system_snapshot_name,operating_system_snapshot_type);

CREATE INDEX xif_os_snap_osid ON operating_system_snapshot
( 
	operating_system_id
);

CREATE INDEX xif_os_snap_snap_type ON operating_system_snapshot
( 
	operating_system_snapshot_type
);

/***********************************************
 * Table: person
 ***********************************************/

CREATE TABLE person
( 
	person_id            serial  NOT NULL ,
	description          varchar(255)  NULL ,
	first_name           varchar(50)  NOT NULL ,
	middle_name          varchar(50)  NULL ,
	last_name            varchar(50)  NOT NULL ,
	name_suffix          varchar(10)  NULL ,
	gender               CHAR(1)  NULL ,
	preferred_first_name varchar(50)  NULL ,
	preferred_last_name  varchar(50)  NULL ,
	nickname             varchar(255)  NULL ,
	birth_date           timestamp with time zone  NULL ,
	diet                 varchar(255)  NULL ,
	shirt_size           varchar(20)  NULL ,
	pant_size            varchar(20)  NULL ,
	hat_size             varchar(20)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person
	ADD CONSTRAINT "pk_person_id" PRIMARY KEY (person_id);

CREATE INDEX xif1person ON person
( 
	diet    
);

CREATE INDEX idx_person_name ON person
( 
	first_name,
	last_name
);

/***********************************************
 * Table: person_account_realm_company
 ***********************************************/

CREATE TABLE person_account_realm_company
( 
	person_id            integer  NOT NULL ,
	company_id           integer  NOT NULL ,
	account_realm_id     integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_account_realm_company
	ADD CONSTRAINT "pk_person_account_realm_company" PRIMARY KEY (person_id,company_id,account_realm_id);

CREATE INDEX xif2person_account_realm_company ON person_account_realm_company
( 
	account_realm_id,
	company_id
);

CREATE INDEX xif3person_account_realm_company ON person_account_realm_company
( 
	person_id
);

/***********************************************
 * Table: person_auth_question
 ***********************************************/

CREATE TABLE person_auth_question
( 
	auth_question_id     integer  NOT NULL ,
	person_id            integer  NOT NULL ,
	user_answer          varchar(255)  NOT NULL ,
	is_active            char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_auth_question
	ADD CONSTRAINT "pk_person_auth_question" PRIMARY KEY (auth_question_id,person_id);

CREATE INDEX xif3person_auth_question ON person_auth_question
( 
	person_id
);

CREATE INDEX ix_person_aq_auth_ques_id ON person_auth_question
( 
	auth_question_id
);

/***********************************************
 * Table: person_company
 ***********************************************/

CREATE TABLE person_company
( 
	company_id           integer  NOT NULL ,
	person_id            integer  NOT NULL ,
	person_company_status character varying(50)  NOT NULL ,
	person_company_relation varchar(50)  NOT NULL ,
	is_exempt            char(1)  NOT NULL ,
	is_management        char(1)  NOT NULL ,
	is_full_time         char(1)  NOT NULL ,
	description          varchar(255)  NULL ,
	position_title       varchar(50)  NULL ,
	hire_date            timestamp with time zone  NULL ,
	termination_date     timestamp with time zone  NULL ,
	manager_person_id    integer  NULL ,
	nickname             varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_company
	ADD CONSTRAINT "pk_person_company" PRIMARY KEY (company_id,person_id);

CREATE INDEX xif3person_company ON person_company
( 
	manager_person_id
);

CREATE INDEX xif5person_company ON person_company
( 
	person_company_status
);

CREATE INDEX xif6person_company ON person_company
( 
	person_company_relation
);

CREATE INDEX xifperson_company_company_id ON person_company
( 
	company_id
);

CREATE INDEX xifperson_company_person_id ON person_company
( 
	person_id
);

/***********************************************
 * Table: person_company_attribute
 ***********************************************/

CREATE TABLE person_company_attribute
( 
	company_id           integer  NOT NULL ,
	person_id            integer  NOT NULL ,
	person_company_attribute_name varchar(50)  NOT NULL ,
	attribute_value      varchar(50)  NULL ,
	attribute_value_timestamp timestamp with time zone  NULL ,
	attribute_value_person_id integer  NULL ,
	start_date           timestamp with time zone  NULL ,
	finish_date          timestamp with time zone  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_company_attribute
	ADD CONSTRAINT "pk_person_company_attr" PRIMARY KEY (company_id,person_id,person_company_attribute_name);

ALTER TABLE person_company_attribute
	ADD CONSTRAINT "ak_person_company_attr_name" UNIQUE (company_id,person_id,person_company_attribute_name);

CREATE INDEX xif1person_company_attribute ON person_company_attribute
( 
	company_id,
	person_id
);

CREATE INDEX xif2person_company_attribute ON person_company_attribute
( 
	attribute_value_person_id
);

CREATE INDEX xif3person_company_attribute ON person_company_attribute
( 
	person_company_attribute_name
);

/***********************************************
 * Table: person_company_badge
 ***********************************************/

CREATE TABLE person_company_badge
( 
	company_id           integer  NOT NULL ,
	person_id            integer  NOT NULL ,
	badge_id             varchar(255)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_company_badge
	ADD CONSTRAINT "pk_person_company_badge" PRIMARY KEY (company_id,person_id,badge_id);

CREATE INDEX xif1person_company_badge ON person_company_badge
( 
	company_id,
	person_id
);

/***********************************************
 * Table: person_contact
 ***********************************************/

CREATE TABLE person_contact
( 
	person_contact_id    serial  NOT NULL ,
	person_id            integer  NOT NULL ,
	person_contact_type  varchar(50)  NOT NULL ,
	person_contact_technology varchar(50)  NOT NULL ,
	person_contact_location_type varchar(50)  NOT NULL ,
	person_contact_privacy varchar(255)  NOT NULL ,
	person_contact_carrier_company_id integer  NULL ,
	iso_country_code     CHAR(2)  NOT NULL ,
	phone_number         varchar(50)  NULL ,
	phone_extension      varchar(10)  NULL ,
	phone_pin            integer  NULL ,
	person_contact_account_name varchar(255)  NULL ,
	person_contact_order integer  NOT NULL ,
	person_contact_notes varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_contact
	ADD CONSTRAINT "pk_person_contact_type" PRIMARY KEY (person_contact_id);

ALTER TABLE person_contact
	ADD CONSTRAINT "ak_prsn_contct_type_order" UNIQUE (person_contact_order,person_id,person_contact_type);

CREATE INDEX xif4person_contact ON person_contact
( 
	person_contact_location_type
);

CREATE INDEX xif5person_contact ON person_contact
( 
	person_contact_carrier_company_id
);

CREATE INDEX xif6person_contact ON person_contact
( 
	person_contact_technology,
	person_contact_type
);

CREATE INDEX xif_person_contact_person_id ON person_contact
( 
	person_id
);

CREATE INDEX xif_person_type_iso_code ON person_contact
( 
	iso_country_code
);

/***********************************************
 * Table: person_image
 ***********************************************/

CREATE TABLE person_image
( 
	person_image_id      serial  NOT NULL ,
	person_id            integer  NOT NULL ,
	person_image_order   integer  NOT NULL ,
	image_type           varchar(50)  NOT NULL ,
	image_blob           oid  NOT NULL ,
	image_checksum       varchar(255)  NULL ,
	image_label          varchar(255)  NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_image
	ADD CONSTRAINT "pk_person_image" PRIMARY KEY (person_image_id);

CREATE INDEX xif3person_image ON person_image
( 
	person_id
);

CREATE INDEX idx_prsnimg_img_type ON person_image
( 
	image_type
);

/***********************************************
 * Table: person_image_usage
 ***********************************************/

CREATE TABLE person_image_usage
( 
	person_image_id      integer  NOT NULL ,
	person_image_usage   varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_image_usage
	ADD CONSTRAINT "pk_person_image_usage" PRIMARY KEY (person_image_id,person_image_usage);

CREATE INDEX xif1person_image_usage ON person_image_usage
( 
	person_image_id
);

CREATE INDEX xif2person_image_usage ON person_image_usage
( 
	person_image_usage
);

/***********************************************
 * Table: person_location
 ***********************************************/

CREATE TABLE person_location
( 
	person_location_id   serial  NOT NULL ,
	person_id            integer  NULL ,
	person_location_type character varying(50)  NULL ,
	site_code            character varying(50)  NULL ,
	physical_address_id  integer  NULL ,
	building             varchar(50)  NULL ,
	floor                varchar(10)  NULL ,
	section              varchar(50)  NULL ,
	seat_number          varchar(10)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_location
	ADD CONSTRAINT "pk_person_location" PRIMARY KEY (person_location_id);

CREATE INDEX xifpersloc_persid ON person_location
( 
	person_id
);

CREATE INDEX xifpersloc_persloctyp ON person_location
( 
	person_location_type
);

CREATE INDEX xifpersloc_physaddrid ON person_location
( 
	physical_address_id
);

CREATE INDEX xifpersloc_sitecode ON person_location
( 
	site_code
);

/***********************************************
 * Table: person_note
 ***********************************************/

CREATE TABLE person_note
( 
	note_id              serial  NOT NULL ,
	person_id            integer  NULL ,
	note_text            varchar(4000)  NOT NULL ,
	note_date            timestamp with time zone  NOT NULL ,
	note_user            varchar(30)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_note
	ADD CONSTRAINT "pk_person_note" PRIMARY KEY (note_id);

CREATE INDEX xif1person_note ON person_note
( 
	person_id
);

/***********************************************
 * Table: person_parking_pass
 ***********************************************/

CREATE TABLE person_parking_pass
( 
	person_parking_pass_id serial  NOT NULL ,
	person_id            integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_parking_pass
	ADD CONSTRAINT "pk_system_parking_pass" PRIMARY KEY (person_parking_pass_id,person_id);

CREATE INDEX xif2person_parking_pass ON person_parking_pass
( 
	person_id
);

/***********************************************
 * Table: person_vehicle
 ***********************************************/

CREATE TABLE person_vehicle
( 
	person_vehicle_id    serial  NOT NULL ,
	person_id            integer  NOT NULL ,
	vehicle_make         varchar(50)  NOT NULL ,
	vehicle_model        varchar(50)  NOT NULL ,
	vehicle_year         varchar(5)  NOT NULL ,
	vehicle_color        varchar(50)  NOT NULL ,
	vehicle_license_plate varchar(8)  NOT NULL ,
	vehicle_license_state CHAR(2)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE person_vehicle
	ADD CONSTRAINT "pk_person_vehicle" PRIMARY KEY (person_vehicle_id);

ALTER TABLE person_vehicle
	ADD CONSTRAINT "ak_uq_person_vehicle_prsnid" UNIQUE (vehicle_license_plate,vehicle_license_state);

CREATE INDEX xif2person_vehicle ON person_vehicle
( 
	person_id
);

/***********************************************
 * Table: physical_address
 ***********************************************/

CREATE TABLE physical_address
( 
	physical_address_id  serial  NOT NULL ,
	physical_address_type varchar(50)  NULL ,
	company_id           integer  NULL ,
	site_rank            integer  NULL ,
	description          varchar(4000)  NULL ,
	display_label        varchar(100)  NULL ,
	address_agent        varchar(100)  NULL ,
	address_housename    varchar(255)  NULL ,
	address_street       varchar(255)  NULL ,
	address_building     varchar(255)  NULL ,
	address_pobox        varchar(255)  NULL ,
	address_neighborhood varchar(255)  NULL ,
	address_city         varchar(100)  NULL ,
	address_subregion    varchar(50)  NULL ,
	address_region       varchar(100)  NULL ,
	postal_code          varchar(20)  NULL ,
	iso_country_code     CHAR(2)  NOT NULL ,
	address_freeform     varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE physical_address
	ADD CONSTRAINT "pk_val_office_site" PRIMARY KEY (physical_address_id);

ALTER TABLE physical_address
	ADD CONSTRAINT "uq_physaddr_compid_siterk" UNIQUE (company_id,site_rank);

CREATE INDEX xif_physaddr_company_id ON physical_address
( 
	company_id
);

CREATE INDEX xif_physaddr_iso_cc ON physical_address
( 
	iso_country_code
);

CREATE INDEX xif_physaddr_type_val ON physical_address
( 
	physical_address_type
);

/***********************************************
 * Table: physical_connection
 ***********************************************/

CREATE TABLE physical_connection
( 
	physical_connection_id serial  NOT NULL ,
	slot1_id             integer  NULL ,
	slot2_id             integer  NULL ,
	cable_type           character varying(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE physical_connection
	ADD CONSTRAINT "pk_physical_connection" PRIMARY KEY (physical_connection_id);

CREATE INDEX xif_physconn_slot1_id ON physical_connection
( 
	slot1_id
);

CREATE INDEX xif_physconn_slot2_id ON physical_connection
( 
	slot2_id
);

CREATE INDEX xif_physical_conn_v_cable_type ON physical_connection
( 
	cable_type
);

/***********************************************
 * Table: physicalish_volume
 ***********************************************/

CREATE TABLE physicalish_volume
( 
	physicalish_volume_id serial  NOT NULL ,
	physicalish_volume_name varchar(50)  NOT NULL ,
	physicalish_volume_type varchar(50)  NOT NULL ,
	device_id            integer  NOT NULL ,
	logical_volume_id    integer  NULL ,
	component_id         integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE physicalish_volume
	ADD CONSTRAINT "pk_physicalish_volume" PRIMARY KEY (physicalish_volume_id);

ALTER TABLE physicalish_volume
	ADD CONSTRAINT "ak_physicalish_volume_devid" UNIQUE (physicalish_volume_id,device_id);

ALTER TABLE physicalish_volume
	ADD CONSTRAINT "ak_physvolname_type_devid" UNIQUE (device_id,physicalish_volume_name,physicalish_volume_type)
	DEFERRABLE  ;

CREATE INDEX xif_physicalish_vol_pvtype ON physicalish_volume
( 
	physicalish_volume_type
);

CREATE INDEX xif_physvol_compid ON physicalish_volume
( 
	component_id
);

CREATE INDEX xif_physvol_device_id ON physicalish_volume
( 
	device_id
);

CREATE INDEX xif_physvol_lvid ON physicalish_volume
( 
	logical_volume_id
);

/***********************************************
 * Table: private_key
 ***********************************************/

CREATE TABLE private_key
( 
	private_key_id       serial  NOT NULL ,
	private_key_encryption_type varchar(50)  NOT NULL ,
	is_active            char(1)  NOT NULL ,
	subject_key_identifier varchar(255)  NULL ,
	private_key          text  NOT NULL ,
	passphrase           varchar(255)  NULL ,
	encryption_key_id    integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE private_key
	ADD CONSTRAINT "pk_private_key" PRIMARY KEY (private_key_id);

ALTER TABLE private_key
	ADD CONSTRAINT "ak_private_key" UNIQUE (subject_key_identifier);

CREATE INDEX xif2private_key ON private_key
( 
	encryption_key_id
);

CREATE INDEX fk_pvtkey_enctype ON private_key
( 
	private_key_encryption_type
);

/***********************************************
 * Table: property
 ***********************************************/

CREATE TABLE property
( 
	property_id          serial  NOT NULL ,
	account_collection_id integer  NULL ,
	account_id           integer  NULL ,
	account_realm_id     integer  NULL ,
	company_collection_id integer  NULL ,
	company_id           integer  NULL ,
	device_collection_id integer  NULL ,
	dns_domain_collection_id integer  NULL ,
	layer2_network_collection_id integer  NULL ,
	layer3_network_collection_id integer  NULL ,
	netblock_collection_id integer  NULL ,
	network_range_id     integer  NULL ,
	operating_system_id  integer  NULL ,
	operating_system_snapshot_id integer  NULL ,
	person_id            integer  NULL ,
	property_name_collection_id integer  NULL ,
	service_environment_collection_id integer  NULL ,
	site_code            character varying(50)  NULL ,
	x509_signed_certificate_id integer  NULL ,
	property_name        varchar(255)  NOT NULL ,
	property_type        varchar(50)  NOT NULL ,
	property_value       varchar(1024)  NULL ,
	property_value_timestamp timestamp without time zone  NULL ,
	property_value_account_collection_id integer  NULL ,
	property_value_device_collection_id integer  NULL ,
	property_value_json  jsonb  NULL ,
	property_value_netblock_collection_id integer  NULL ,
	property_value_password_type character varying(50)  NULL ,
	property_value_person_id integer  NULL ,
	property_value_sw_package_id integer  NULL ,
	property_value_token_collection_id integer  NULL ,
	property_rank        integer  NULL ,
	start_date           timestamp without time zone  NULL ,
	finish_date          timestamp without time zone  NULL ,
	is_enabled           char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE property
	ADD CONSTRAINT "pk_property" PRIMARY KEY (property_id);

CREATE INDEX xif30property ON property
( 
	layer2_network_collection_id
);

CREATE INDEX xif31property ON property
( 
	layer3_network_collection_id
);

CREATE INDEX xif32property ON property
( 
	network_range_id
);

CREATE INDEX xif33property ON property
( 
	x509_signed_certificate_id
);

CREATE INDEX xif34property ON property
( 
	service_environment_collection_id ASC
);

CREATE INDEX xifprop_account_id ON property
( 
	account_id
);

CREATE INDEX xifprop_acctcol_id ON property
( 
	account_collection_id
);

CREATE INDEX xifprop_compid ON property
( 
	company_id
);

CREATE INDEX xifprop_devcolid ON property
( 
	device_collection_id
);

CREATE INDEX xifprop_nmtyp ON property
( 
	property_name,
	property_type
);

CREATE INDEX xifprop_osid ON property
( 
	operating_system_id
);

CREATE INDEX xifprop_pval_acct_colid ON property
( 
	property_value_account_collection_id
);

CREATE INDEX xifprop_pval_pwdtyp ON property
( 
	property_value_password_type
);

CREATE INDEX xifprop_pval_swpkgid ON property
( 
	property_value_sw_package_id
);

CREATE INDEX xifprop_pval_tokcolid ON property
( 
	property_value_token_collection_id
);

CREATE INDEX xifprop_site_code ON property
( 
	site_code
);

CREATE INDEX xif_property_acctrealmid ON property
( 
	account_realm_id
);

CREATE INDEX xif_property_dns_dom_collect ON property
( 
	dns_domain_collection_id
);

CREATE INDEX xif_property_nblk_coll_id ON property
( 
	netblock_collection_id
);

CREATE INDEX xif_property_person_id ON property
( 
	person_id
);

CREATE INDEX xif_property_prop_coll_id ON property
( 
	property_name_collection_id
);

CREATE INDEX xif_property_pv_nblkcol_id ON property
( 
	property_value_netblock_collection_id
);

CREATE INDEX xif_property_val_prsnid ON property
( 
	property_value_person_id
);

CREATE INDEX xif_prop_compcoll_id ON property
( 
	company_collection_id
);

CREATE INDEX xif_prop_os_snapshot ON property
( 
	operating_system_snapshot_id
);

CREATE INDEX xif_prop_pv_devcolid ON property
( 
	property_value_device_collection_id
);

/***********************************************
 * Table: property_name_collection
 ***********************************************/

CREATE TABLE property_name_collection
( 
	property_name_collection_id serial  NOT NULL ,
	property_name_collection_name varchar(255)  NOT NULL ,
	property_name_collection_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE property_name_collection
	ADD CONSTRAINT "pk_property_collection" PRIMARY KEY (property_name_collection_id);

ALTER TABLE property_name_collection
	ADD CONSTRAINT "ak_uqpropcoll_name_type" UNIQUE (property_name_collection_name,property_name_collection_type);

CREATE INDEX xif1property_name_collection ON property_name_collection
( 
	property_name_collection_type
);

/***********************************************
 * Table: property_name_collection_hier
 ***********************************************/

CREATE TABLE property_name_collection_hier
( 
	property_name_collection_id integer  NOT NULL ,
	child_property_name_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE property_name_collection_hier
	ADD CONSTRAINT "pk_property_collection_hier" PRIMARY KEY (property_name_collection_id,child_property_name_collection_id);

CREATE INDEX xif1property_name_collection_hier ON property_name_collection_hier
( 
	property_name_collection_id
);

CREATE INDEX xif2property_name_collection_hier ON property_name_collection_hier
( 
	child_property_name_collection_id
);

/***********************************************
 * Table: property_name_collection_property_name
 ***********************************************/

CREATE TABLE property_name_collection_property_name
( 
	property_name_collection_id integer  NOT NULL ,
	property_name        character varying(255)  NOT NULL ,
	property_type        character varying(50)  NOT NULL ,
	property_id_rank     integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE property_name_collection_property_name
	ADD CONSTRAINT "pk_property_collection_property" PRIMARY KEY (property_name_collection_id,property_name,property_type);

ALTER TABLE property_name_collection_property_name
	ADD CONSTRAINT "xakprop_coll_prop_rank" UNIQUE (property_name_collection_id,property_id_rank);

CREATE INDEX xifprop_coll_prop_namtyp ON property_name_collection_property_name
( 
	property_name,
	property_type
);

CREATE INDEX xifprop_coll_prop_prop_coll_id ON property_name_collection_property_name
( 
	property_name_collection_id
);

/***********************************************
 * Table: pseudo_klogin
 ***********************************************/

CREATE TABLE pseudo_klogin
( 
	pseudo_klogin_id     serial  NOT NULL ,
	principal            varchar(100)  NULL ,
	dest_account_id      integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE pseudo_klogin
	ADD CONSTRAINT "pk_pseudo_klogin" PRIMARY KEY (pseudo_klogin_id);

CREATE INDEX idx_psklogin_dacctid ON pseudo_klogin
( 
	dest_account_id
);

/***********************************************
 * Table: rack
 ***********************************************/

CREATE TABLE rack
( 
	rack_id              serial  NOT NULL ,
	site_code            character varying(50)  NOT NULL ,
	room                 varchar(50)  NULL ,
	sub_room             varchar(50)  NULL ,
	rack_row             varchar(50)  NULL ,
	rack_name            varchar(50)  NOT NULL ,
	rack_style           varchar(50)  NOT NULL ,
	rack_type            varchar(255)  NULL ,
	description          varchar(255)  NULL ,
	rack_height_in_u     integer  NOT NULL ,
	display_from_bottom  CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE rack
	ADD CONSTRAINT "pk_rack_id" PRIMARY KEY (rack_id);

ALTER TABLE rack
	ADD CONSTRAINT "ak_uq_site_room_sub_r_rack" UNIQUE (site_code,room,sub_room,rack_row,rack_name);

CREATE INDEX xif2rack ON rack
( 
	rack_type
);

/***********************************************
 * Table: rack_location
 ***********************************************/

CREATE TABLE rack_location
( 
	rack_location_id     serial  NOT NULL ,
	rack_id              integer  NOT NULL ,
	rack_u_offset_of_device_top integer  NOT NULL ,
	rack_side            varchar(10)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE rack_location
	ADD CONSTRAINT "pk_rack_location" PRIMARY KEY (rack_location_id);

ALTER TABLE rack_location
	ADD CONSTRAINT "ak_uq_rack_offset_sid_location" UNIQUE (rack_id,rack_u_offset_of_device_top,rack_side);

/***********************************************
 * Table: service_environment
 ***********************************************/

CREATE TABLE service_environment
( 
	service_environment_id serial  NOT NULL ,
	service_environment_name varchar(50)  NOT NULL ,
	production_state     varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE service_environment
	ADD CONSTRAINT "pk_service_environment" PRIMARY KEY (service_environment_id);

CREATE INDEX xif1service_environment ON service_environment
( 
	production_state
);

/***********************************************
 * Table: service_environment_collection
 ***********************************************/

CREATE TABLE service_environment_collection
( 
	service_environment_collection_id serial  NOT NULL ,
	service_environment_collection_name varchar(50)  NOT NULL ,
	service_environment_collection_type varchar(50)  NULL ,
	description          varchar(4000)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE service_environment_collection
	ADD CONSTRAINT "pk_service_environment_collection" PRIMARY KEY (service_environment_collection_id);

ALTER TABLE service_environment_collection
	ADD CONSTRAINT "ak_val_svc_env_name_type" UNIQUE (service_environment_collection_name,service_environment_collection_type);

CREATE INDEX xif1service_environment_collection ON service_environment_collection
( 
	service_environment_collection_type
);

/***********************************************
 * Table: service_environment_collection_hier
 ***********************************************/

CREATE TABLE service_environment_collection_hier
( 
	service_environment_collection_id integer  NOT NULL ,
	child_service_environment_collection_id integer  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE service_environment_collection_hier
	ADD CONSTRAINT "pk_service_environment_hier" PRIMARY KEY (service_environment_collection_id,child_service_environment_collection_id);

CREATE INDEX xif1service_environment_collection_hier ON service_environment_collection_hier
( 
	child_service_environment_collection_id
);

CREATE INDEX xif2service_environment_collection_hier ON service_environment_collection_hier
( 
	service_environment_collection_id
);

/***********************************************
 * Table: service_environment_collection_service_environment
 ***********************************************/

CREATE TABLE service_environment_collection_service_environment
( 
	service_environment_collection_id integer  NOT NULL ,
	service_environment_id integer  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE service_environment_collection_service_environment
	ADD CONSTRAINT "pk_svc_environment_coll_svc_env" PRIMARY KEY (service_environment_collection_id,service_environment_id);

CREATE INDEX xif1service_environment_collection_service_environment ON service_environment_collection_service_environment
( 
	service_environment_id
);

CREATE INDEX xif2service_environment_collection_service_environment ON service_environment_collection_service_environment
( 
	service_environment_collection_id
);

/***********************************************
 * Table: shared_netblock
 ***********************************************/

CREATE TABLE shared_netblock
( 
	shared_netblock_id   serial  NOT NULL ,
	shared_netblock_protocol varchar(50)  NOT NULL ,
	netblock_id          integer  NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE shared_netblock
	ADD CONSTRAINT "pk_shared_netblock" PRIMARY KEY (shared_netblock_id);

ALTER TABLE shared_netblock
	ADD CONSTRAINT "ak_shared_netblock_netblock" UNIQUE (netblock_id);

CREATE INDEX xif1shared_netblock ON shared_netblock
( 
	shared_netblock_protocol
);

CREATE INDEX xif2shared_netblock ON shared_netblock
( 
	netblock_id
);

/***********************************************
 * Table: shared_netblock_layer3_interface
 ***********************************************/

CREATE TABLE shared_netblock_layer3_interface
( 
	shared_netblock_id   integer  NOT NULL ,
	layer3_interface_id  integer  NOT NULL ,
	priority             integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE shared_netblock_layer3_interface
	ADD CONSTRAINT "pk_ip_group_network_interface" PRIMARY KEY (shared_netblock_id,layer3_interface_id);

CREATE INDEX xif1shared_netblock_layer3_interface ON shared_netblock_layer3_interface
( 
	shared_netblock_id
);

CREATE INDEX xif2shared_netblock_layer3_interface ON shared_netblock_layer3_interface
( 
	layer3_interface_id
);

/***********************************************
 * Table: site
 ***********************************************/

CREATE TABLE site
( 
	site_code            varchar(50)  NOT NULL ,
	colo_company_id      integer  NULL ,
	physical_address_id  integer  NULL ,
	site_status          varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE site
	ADD CONSTRAINT "pk_site_code" PRIMARY KEY (site_code);

CREATE INDEX fk_site_colo_company_id ON site
( 
	colo_company_id
);

CREATE INDEX xifsite_physaddr_id ON site
( 
	physical_address_id
);

/***********************************************
 * Table: slot
 ***********************************************/

CREATE TABLE slot
( 
	slot_id              serial  NOT NULL ,
	component_id         integer  NOT NULL ,
	slot_name            varchar(50)  NOT NULL ,
	slot_index           integer  NULL ,
	slot_type_id         integer  NOT NULL ,
	component_type_slot_template_id integer  NULL ,
	is_enabled           char(1)  NOT NULL ,
	physical_label       varchar(50)  NULL ,
	mac_address          macaddr  NULL ,
	description          varchar(255)  NULL ,
	slot_x_offset        integer  NULL ,
	slot_y_offset        integer  NULL ,
	slot_z_offset        integer  NULL ,
	slot_side            varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE slot
	ADD CONSTRAINT "pk_slot_id" PRIMARY KEY (slot_id);

ALTER TABLE slot
	ADD CONSTRAINT "ak_slot_slot_type_id" UNIQUE (slot_id,slot_type_id);

ALTER TABLE slot
	ADD CONSTRAINT "uq_slot_cmp_slt_tmplt_id" UNIQUE (component_id,component_type_slot_template_id);

CREATE INDEX xif_slot_cmp_typ_tmp_id ON slot
( 
	component_type_slot_template_id
);

CREATE INDEX xif_slot_component_id ON slot
( 
	component_id
);

CREATE INDEX xif_slot_slot_type_id ON slot
( 
	slot_type_id
);

/***********************************************
 * Table: slot_type
 ***********************************************/

CREATE TABLE slot_type
( 
	slot_type_id         serial  NOT NULL ,
	slot_type            varchar(50)  NOT NULL ,
	slot_function        character varying(50)  NOT NULL ,
	slot_physical_interface_type character varying(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	remote_slot_permitted char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE slot_type
	ADD CONSTRAINT "pk_slot_type" PRIMARY KEY (slot_type_id);

ALTER TABLE slot_type
	ADD CONSTRAINT "ak_slot_type_name_type" UNIQUE (slot_type,slot_function);

CREATE INDEX xif_slot_type_physint_func ON slot_type
( 
	slot_physical_interface_type,
	slot_function
);

CREATE INDEX xif_slot_type_slt_func ON slot_type
( 
	slot_function
);

/***********************************************
 * Table: slot_type_permitted_component_slot_type
 ***********************************************/

CREATE TABLE slot_type_permitted_component_slot_type
( 
	slot_type_id         integer  NOT NULL ,
	component_slot_type_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE slot_type_permitted_component_slot_type
	ADD CONSTRAINT "pk_slot_type_prmt_comp_slot_typ" PRIMARY KEY (slot_type_id,component_slot_type_id);

CREATE INDEX xif_stpcst_cmp_slt_typ_id ON slot_type_permitted_component_slot_type
( 
	slot_type_id
);

CREATE INDEX xif_stpcst_slot_type_id ON slot_type_permitted_component_slot_type
( 
	component_slot_type_id
);

/***********************************************
 * Table: slot_type_permitted_remote_slot_type
 ***********************************************/

CREATE TABLE slot_type_permitted_remote_slot_type
( 
	slot_type_id         integer  NOT NULL ,
	remote_slot_type_id  integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE slot_type_permitted_remote_slot_type
	ADD CONSTRAINT "pk_slot_type_prmt_rem_slot_type" PRIMARY KEY (slot_type_id,remote_slot_type_id);

CREATE INDEX xif_stprst_remote_slot_type_id ON slot_type_permitted_remote_slot_type
( 
	remote_slot_type_id
);

CREATE INDEX xif_stprst_slot_type_id ON slot_type_permitted_remote_slot_type
( 
	slot_type_id
);

/***********************************************
 * Table: ssh_key
 ***********************************************/

CREATE TABLE ssh_key
( 
	ssh_key_id           serial  NOT NULL ,
	ssh_key_type         varchar(50)  NULL ,
	ssh_public_key       varchar(4096)  NOT NULL ,
	ssh_private_key      varchar(4096)  NULL ,
	encryption_key_id    integer  NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE ssh_key
	ADD CONSTRAINT "pk_ssh_key" PRIMARY KEY (ssh_key_id);

ALTER TABLE ssh_key
	ADD CONSTRAINT "ak_ssh_key_private_key" UNIQUE (ssh_private_key);

ALTER TABLE ssh_key
	ADD CONSTRAINT "ak_ssh_key_public_key" UNIQUE (ssh_public_key);

CREATE INDEX xif1ssh_key ON ssh_key
( 
	encryption_key_id
);

CREATE INDEX xif2ssh_key ON ssh_key
( 
	ssh_key_type
);

/***********************************************
 * Table: static_route
 ***********************************************/

CREATE TABLE static_route
( 
	static_route_id      serial  NOT NULL ,
	device_source_id     integer  NOT NULL ,
	network_interface_destination_id integer  NOT NULL ,
	netblock_id          integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE static_route
	ADD CONSTRAINT "pk_static_route_id" PRIMARY KEY (static_route_id);

CREATE INDEX idx_staticrt_devsrcid ON static_route
( 
	device_source_id
);

CREATE INDEX idx_staticrt_netblockid ON static_route
( 
	netblock_id
);

CREATE INDEX idx_staticrt_netintdstid ON static_route
( 
	network_interface_destination_id
);

/***********************************************
 * Table: static_route_template
 ***********************************************/

CREATE TABLE static_route_template
( 
	static_route_template_id serial  NOT NULL ,
	netblock_source_id   integer  NOT NULL ,
	network_interface_destination_id integer  NOT NULL ,
	netblock_id          integer  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE static_route_template
	ADD CONSTRAINT "pk_static_route_template" PRIMARY KEY (static_route_template_id);

/***********************************************
 * Table: sudo_account_collection_device_collection
 ***********************************************/

CREATE TABLE sudo_account_collection_device_collection
( 
	sudo_alias_name      character varying(50)  NOT NULL ,
	device_collection_id integer  NOT NULL ,
	account_collection_id integer  NOT NULL ,
	run_as_account_collection_id integer  NULL ,
	requires_password    CHAR(1)  NOT NULL ,
	can_exec_child       CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT "pk_sudo_acct_col_dev_coll" PRIMARY KEY (sudo_alias_name,device_collection_id,account_collection_id);

/***********************************************
 * Table: sudo_alias
 ***********************************************/

CREATE TABLE sudo_alias
( 
	sudo_alias_name      varchar(50)  NOT NULL ,
	sudo_alias_value     varchar(4000)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE sudo_alias
	ADD CONSTRAINT "pk_sudo_alias" PRIMARY KEY (sudo_alias_name);

/***********************************************
 * Table: sw_package
 ***********************************************/

CREATE TABLE sw_package
( 
	sw_package_id        serial  NOT NULL ,
	sw_package_name      varchar(50)  NOT NULL ,
	sw_package_type      character varying(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE sw_package
	ADD CONSTRAINT "pk_sw_package" PRIMARY KEY (sw_package_id);

COMMENT ON CONSTRAINT pk_sw_package ON sw_package
	 IS 'This should actually be lower(sw_package_name) but erwin isn''t being cooperative.';

/***********************************************
 * Table: ticketing_system
 ***********************************************/

CREATE TABLE ticketing_system
( 
	ticketing_system_id  serial  NOT NULL ,
	ticketing_system_name varchar(50)  NOT NULL ,
	ticketing_system_url varchar(255)  NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE ticketing_system
	ADD CONSTRAINT "pk_ticketing_system_id" PRIMARY KEY (ticketing_system_id);

/***********************************************
 * Table: token
 ***********************************************/

CREATE TABLE token
( 
	token_id             serial  NOT NULL ,
	token_type           character varying(50)  NOT NULL ,
	token_status         varchar(50)  NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	token_serial         varchar(20)  NULL ,
	zero_time            timestamp with time zone  NULL ,
	time_modulo          integer  NULL ,
	time_skew            integer  NULL ,
	token_key            varchar(512)  NULL ,
	encryption_key_id    integer  NULL ,
	token_password       varchar(128)  NULL ,
	expire_time          timestamp with time zone  NULL ,
	is_token_locked      char(1)  NOT NULL ,
	token_unlock_time    timestamp with time zone  NULL ,
	bad_logins           integer  NULL ,
	last_updated         timestamp with time zone  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE token
	ADD CONSTRAINT "pk_token" PRIMARY KEY (token_id);

ALTER TABLE token
	ADD CONSTRAINT "ak_token_token_key" UNIQUE (token_key);

CREATE INDEX idx_token_tokenstatus ON token
( 
	token_status
);

CREATE INDEX idx_token_tokentype ON token
( 
	token_type
);

/***********************************************
 * Table: token_collection
 ***********************************************/

CREATE TABLE token_collection
( 
	token_collection_id  serial  NOT NULL ,
	token_collection_name varchar(50)  NOT NULL ,
	token_collection_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	external_id          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE token_collection
	ADD CONSTRAINT "pk_token_collection" PRIMARY KEY (token_collection_id);

ALTER TABLE token_collection
	ADD CONSTRAINT "uq_token_coll_name_type" UNIQUE (token_collection_name,token_collection_type);

/***********************************************
 * Table: token_collection_hier
 ***********************************************/

CREATE TABLE token_collection_hier
( 
	token_collection_id  integer  NOT NULL ,
	child_token_collection_id integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE token_collection_hier
	ADD CONSTRAINT "pk_token_collection_hier" PRIMARY KEY (token_collection_id,child_token_collection_id);

CREATE INDEX xif_tok_col_hier_ch_tok_colid ON token_collection_hier
( 
	token_collection_id
);

CREATE INDEX xif_tok_col_hier_tok_colid ON token_collection_hier
( 
	child_token_collection_id
);

/***********************************************
 * Table: token_collection_token
 ***********************************************/

CREATE TABLE token_collection_token
( 
	token_collection_id  integer  NOT NULL ,
	token_id             integer  NOT NULL ,
	token_id_rank        integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE token_collection_token
	ADD CONSTRAINT "pk_token_collection_token" PRIMARY KEY (token_collection_id,token_id);

ALTER TABLE token_collection_token
	ADD CONSTRAINT "ak_tokcoll_tok_tok_id" UNIQUE (token_collection_id,token_id_rank);

CREATE INDEX idx_tok_col_token_tok_col_id ON token_collection_token
( 
	token_collection_id
);

CREATE INDEX idx_tok_col_token_tok_id ON token_collection_token
( 
	token_id
);

/***********************************************
 * Table: token_sequence
 ***********************************************/

CREATE TABLE token_sequence
( 
	token_id             integer  NOT NULL ,
	token_sequence       integer  NOT NULL ,
	last_updated         timestamp with time zone  NOT NULL 
);

ALTER TABLE token_sequence
	ADD CONSTRAINT "pk_token_sequence" PRIMARY KEY (token_id);

/***********************************************
 * Table: unix_group
 ***********************************************/

CREATE TABLE unix_group
( 
	account_collection_id integer  NOT NULL ,
	unix_gid             integer  NOT NULL ,
	group_password       varchar(20)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE unix_group
	ADD CONSTRAINT "pk_unix_group" PRIMARY KEY (account_collection_id);

ALTER TABLE unix_group
	ADD CONSTRAINT "ak_unix_group_unix_gid" UNIQUE (unix_gid);

CREATE UNIQUE INDEX xifunixgrp_uclass_id ON unix_group
( 
	account_collection_id
);

/***********************************************
 * Table: val_account_collection_relation
 ***********************************************/

CREATE TABLE val_account_collection_relation
( 
	account_collection_relation varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_account_collection_relation
	ADD CONSTRAINT "pk_val_account_collection_relation" PRIMARY KEY (account_collection_relation);

/***********************************************
 * Table: val_account_collection_type
 ***********************************************/

CREATE TABLE val_account_collection_type
( 
	account_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	is_infrastructure_type char(1)  NOT NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	account_realm_id     integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_account_collection_type
	ADD CONSTRAINT "pk_val_account_collection_type" PRIMARY KEY (account_collection_type);

CREATE INDEX xif1val_account_collection_type ON val_account_collection_type
( 
	account_realm_id
);

/***********************************************
 * Table: val_account_role
 ***********************************************/

CREATE TABLE val_account_role
( 
	account_role         varchar(50)  NOT NULL ,
	uid_gid_forced       char(1)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_account_role
	ADD CONSTRAINT "pk_val_account_role" PRIMARY KEY (account_role);

/***********************************************
 * Table: val_account_type
 ***********************************************/

CREATE TABLE val_account_type
( 
	account_type         varchar(50)  NOT NULL ,
	is_person            CHAR(1)  NOT NULL ,
	uid_gid_forced       char(1)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_account_type
	ADD CONSTRAINT "pk_val_account_type" PRIMARY KEY (account_type);

CREATE INDEX idx_vaccount_type_isperson ON val_account_type
( 
	is_person
);

/***********************************************
 * Table: val_app_key
 ***********************************************/

CREATE TABLE val_app_key
( 
	appaal_group_name    varchar(50)  NOT NULL ,
	app_key              varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_app_key
	ADD CONSTRAINT "pk_val_app_key" PRIMARY KEY (appaal_group_name,app_key);

CREATE INDEX xif1val_app_key ON val_app_key
( 
	appaal_group_name
);

/***********************************************
 * Table: val_app_key_values
 ***********************************************/

CREATE TABLE val_app_key_values
( 
	appaal_group_name    character varying(50)  NOT NULL ,
	app_key              character varying(50)  NOT NULL ,
	app_value            varchar(4000)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_app_key_values
	ADD CONSTRAINT "pk_val_app_key_values" PRIMARY KEY (appaal_group_name,app_key,app_value);

/***********************************************
 * Table: val_appaal_group_name
 ***********************************************/

CREATE TABLE val_appaal_group_name
( 
	appaal_group_name    varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_appaal_group_name
	ADD CONSTRAINT "pk_val_appaal_group_name" PRIMARY KEY (appaal_group_name);

/***********************************************
 * Table: val_approval_chain_response_period
 ***********************************************/

CREATE TABLE val_approval_chain_response_period
( 
	approval_chain_response_period varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_approval_chain_response_period
	ADD CONSTRAINT "pk_val_approval_chain_resp_prd" PRIMARY KEY (approval_chain_response_period);

/***********************************************
 * Table: val_approval_expiration_action
 ***********************************************/

CREATE TABLE val_approval_expiration_action
( 
	approval_expiration_action varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_approval_expiration_action
	ADD CONSTRAINT "pk_val_approval_expiration_action" PRIMARY KEY (approval_expiration_action);

/***********************************************
 * Table: val_approval_notifty_type
 ***********************************************/

CREATE TABLE val_approval_notifty_type
( 
	approval_notify_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_approval_notifty_type
	ADD CONSTRAINT "pk_val_approval_notify_type" PRIMARY KEY (approval_notify_type);

/***********************************************
 * Table: val_approval_process_type
 ***********************************************/

CREATE TABLE val_approval_process_type
( 
	approval_process_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_approval_process_type
	ADD CONSTRAINT "pk_val_approval_process_type" PRIMARY KEY (approval_process_type);

/***********************************************
 * Table: val_approval_type
 ***********************************************/

CREATE TABLE val_approval_type
( 
	approval_type        varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_approval_type
	ADD CONSTRAINT "pk_val_approval_type" PRIMARY KEY (approval_type);

/***********************************************
 * Table: val_attestation_frequency
 ***********************************************/

CREATE TABLE val_attestation_frequency
( 
	attestation_frequency varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_attestation_frequency
	ADD CONSTRAINT "pk_val_attestation_frequency" PRIMARY KEY (attestation_frequency);

/***********************************************
 * Table: val_auth_question
 ***********************************************/

CREATE TABLE val_auth_question
( 
	auth_question_id     serial  NOT NULL ,
	question_text        varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_auth_question
	ADD CONSTRAINT "pk_val_auth_question" PRIMARY KEY (auth_question_id);

/***********************************************
 * Table: val_auth_resource
 ***********************************************/

CREATE TABLE val_auth_resource
( 
	auth_resource        varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_auth_resource
	ADD CONSTRAINT "pk_val_auth_resource" PRIMARY KEY (auth_resource);

/***********************************************
 * Table: val_badge_status
 ***********************************************/

CREATE TABLE val_badge_status
( 
	badge_status         varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_badge_status
	ADD CONSTRAINT "pk_val_badge_status" PRIMARY KEY (badge_status);

/***********************************************
 * Table: val_cable_type
 ***********************************************/

CREATE TABLE val_cable_type
( 
	cable_type           varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_cable_type
	ADD CONSTRAINT "pk_cable_type" PRIMARY KEY (cable_type);

/***********************************************
 * Table: val_company_collection_type
 ***********************************************/

CREATE TABLE val_company_collection_type
( 
	company_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	is_infrastructure_type char(1)  NOT NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_company_collection_type
	ADD CONSTRAINT "pk_company_collection_type" PRIMARY KEY (company_collection_type);

/***********************************************
 * Table: val_company_type
 ***********************************************/

CREATE TABLE val_company_type
( 
	company_type         varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	company_type_purpose varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_company_type
	ADD CONSTRAINT "pk_val_company_type" PRIMARY KEY (company_type);

CREATE INDEX xif_v_comptyp_comptyppurp ON val_company_type
( 
	company_type_purpose
);

/***********************************************
 * Table: val_company_type_purpose
 ***********************************************/

CREATE TABLE val_company_type_purpose
( 
	company_type_purpose varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_company_type_purpose
	ADD CONSTRAINT "pk_val_company_type_purpose" PRIMARY KEY (company_type_purpose);

/***********************************************
 * Table: val_component_function
 ***********************************************/

CREATE TABLE val_component_function
( 
	component_function   varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_component_function
	ADD CONSTRAINT "pk_val_component_function" PRIMARY KEY (component_function);

/***********************************************
 * Table: val_component_property
 ***********************************************/

CREATE TABLE val_component_property
( 
	component_property_name varchar(50)  NOT NULL ,
	component_property_type character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	is_multivalue        char(1)  NOT NULL ,
	property_data_type   varchar(50)  NOT NULL ,
	permit_component_type_id char(10)  NOT NULL ,
	required_component_type_id integer  NULL ,
	permit_component_function char(10)  NOT NULL ,
	required_component_function character varying(50)  NULL ,
	permit_component_id  char(10)  NOT NULL ,
	permit_inter_component_connection_id char(10)  NOT NULL ,
	permit_slot_type_id  char(10)  NOT NULL ,
	required_slot_type_id integer  NULL ,
	permit_slot_function char(10)  NOT NULL ,
	required_slot_function character varying(50)  NULL ,
	permit_slot_id       char(10)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_component_property
	ADD CONSTRAINT "pk_val_component_property" PRIMARY KEY (component_property_name,component_property_type);

CREATE INDEX xif_prop_rqd_slt_func ON val_component_property
( 
	required_slot_function
);

CREATE INDEX xif_vcomp_prop_comp_prop_type ON val_component_property
( 
	component_property_type
);

CREATE INDEX xif_vcomp_prop_rqd_cmpfunc ON val_component_property
( 
	required_component_function
);

CREATE INDEX xif_vcomp_prop_rqd_cmptypid ON val_component_property
( 
	required_component_type_id
);

CREATE INDEX xif_vcomp_prop_rqd_slttyp_id ON val_component_property
( 
	required_slot_type_id
);

/***********************************************
 * Table: val_component_property_type
 ***********************************************/

CREATE TABLE val_component_property_type
( 
	component_property_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	is_multivalue        char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_component_property_type
	ADD CONSTRAINT "pk_val_component_property_type" PRIMARY KEY (component_property_type);

/***********************************************
 * Table: val_component_property_value
 ***********************************************/

CREATE TABLE val_component_property_value
( 
	component_property_name character varying(50)  NOT NULL ,
	component_property_type varchar(50)  NOT NULL ,
	valid_property_value varchar(255)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_component_property_value
	ADD CONSTRAINT "pk_val_component_property_value" PRIMARY KEY (component_property_name,component_property_type,valid_property_value);

CREATE INDEX xif_comp_prop_val_nametyp ON val_component_property_value
( 
	component_property_name,
	component_property_type
);

/***********************************************
 * Table: val_contract_type
 ***********************************************/

CREATE TABLE val_contract_type
( 
	contract_type        varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_contract_type
	ADD CONSTRAINT "pk_val_contract_type" PRIMARY KEY (contract_type);

/***********************************************
 * Table: val_country_code
 ***********************************************/

CREATE TABLE val_country_code
( 
	iso_country_code     CHAR(2)  NOT NULL ,
	dial_country_code    varchar(4)  NOT NULL ,
	primary_iso_currency_code CHAR(3)  NULL ,
	country_name         varchar(255)  NULL ,
	display_priority     integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_country_code
	ADD CONSTRAINT "pk_val_country_code" PRIMARY KEY (iso_country_code);

CREATE INDEX xif1val_country_code ON val_country_code
( 
	primary_iso_currency_code
);

/***********************************************
 * Table: val_device_collection_type
 ***********************************************/

CREATE TABLE val_device_collection_type
( 
	device_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_device_collection_type
	ADD CONSTRAINT "pk_val_device_collection_type" PRIMARY KEY (device_collection_type);

/***********************************************
 * Table: val_device_management_controller_type
 ***********************************************/

CREATE TABLE val_device_management_controller_type
( 
	device_mgmt_control_type varchar(255)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_device_management_controller_type
	ADD CONSTRAINT "pk_val_device_mgmt_ctrl_type" PRIMARY KEY (device_mgmt_control_type);

/***********************************************
 * Table: val_device_status
 ***********************************************/

CREATE TABLE val_device_status
( 
	device_status        varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_device_status
	ADD CONSTRAINT "pk_val_status" PRIMARY KEY (device_status);

/***********************************************
 * Table: val_diet
 ***********************************************/

CREATE TABLE val_diet
( 
	diet                 varchar(255)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_diet
	ADD CONSTRAINT "pk_val_diet" PRIMARY KEY (diet);

/***********************************************
 * Table: val_dns_class
 ***********************************************/

CREATE TABLE val_dns_class
( 
	dns_class            varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_dns_class
	ADD CONSTRAINT "pk_val_dns_class" PRIMARY KEY (dns_class);

/***********************************************
 * Table: val_dns_domain_collection_type
 ***********************************************/

CREATE TABLE val_dns_domain_collection_type
( 
	dns_domain_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_dns_domain_collection_type
	ADD CONSTRAINT "pk_val_dns_domain_collection_type" PRIMARY KEY (dns_domain_collection_type);

CREATE TABLE val_dns_domain_type
( 
	dns_domain_type      varchar(50)  NOT NULL ,
	can_generate         char(1)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_dns_domain_type
	ADD CONSTRAINT "pkval_dns_domain_type" PRIMARY KEY (dns_domain_type);

/***********************************************
 * Table: val_dns_record_relation_type
 ***********************************************/

CREATE TABLE val_dns_record_relation_type
( 
	dns_record_relation_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_dns_record_relation_type
	ADD CONSTRAINT "pk_val_dns_record_relation_typ" PRIMARY KEY (dns_record_relation_type);

/***********************************************
 * Table: val_dns_srv_service
 ***********************************************/

CREATE TABLE val_dns_srv_service
( 
	dns_srv_service      varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_dns_srv_service
	ADD CONSTRAINT "pk_val_dns_srv_srvice" PRIMARY KEY (dns_srv_service);

/***********************************************
 * Table: val_dns_type
 ***********************************************/

CREATE TABLE val_dns_type
( 
	dns_type             varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	id_type              varchar(10)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_dns_type
	ADD CONSTRAINT "pk_val_dns_type" PRIMARY KEY (dns_type);

/***********************************************
 * Table: val_encapsulation_mode
 ***********************************************/

CREATE TABLE val_encapsulation_mode
( 
	encapsulation_mode   varchar(50)  NOT NULL ,
	encapsulation_type   character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_encapsulation_mode
	ADD CONSTRAINT "pk_val_encapsulation_mode" PRIMARY KEY (encapsulation_mode,encapsulation_type);

CREATE INDEX xif_val_encap_mode_type ON val_encapsulation_mode
( 
	encapsulation_type
);

/***********************************************
 * Table: val_encapsulation_type
 ***********************************************/

CREATE TABLE val_encapsulation_type
( 
	encapsulation_type   varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_encapsulation_type
	ADD CONSTRAINT "pk_val_encapsulation_type" PRIMARY KEY (encapsulation_type);

/***********************************************
 * Table: val_encryption_key_purpose
 ***********************************************/

CREATE TABLE val_encryption_key_purpose
( 
	encryption_key_purpose varchar(50)  NOT NULL ,
	encryption_key_purpose_version serial  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_encryption_key_purpose
	ADD CONSTRAINT "pk_val_encryption_key_purpose" PRIMARY KEY (encryption_key_purpose,encryption_key_purpose_version);

/***********************************************
 * Table: val_encryption_method
 ***********************************************/

CREATE TABLE val_encryption_method
( 
	encryption_method    varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_encryption_method
	ADD CONSTRAINT "pk_val_encryption_method" PRIMARY KEY (encryption_method);

/***********************************************
 * Table: val_filesystem_type
 ***********************************************/

CREATE TABLE val_filesystem_type
( 
	filesystem_type      varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_filesystem_type
	ADD CONSTRAINT "pk_val_filesytem_type" PRIMARY KEY (filesystem_type);

/***********************************************
 * Table: val_image_type
 ***********************************************/

CREATE TABLE val_image_type
( 
	image_type           varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_image_type
	ADD CONSTRAINT "pk_val_image_type" PRIMARY KEY (image_type);

/***********************************************
 * Table: val_ip_namespace
 ***********************************************/

CREATE TABLE val_ip_namespace
( 
	ip_namespace         varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_ip_namespace
	ADD CONSTRAINT "pk_val_ip_namespace" PRIMARY KEY (ip_namespace);

/***********************************************
 * Table: val_iso_currency_code
 ***********************************************/

CREATE TABLE val_iso_currency_code
( 
	iso_currency_code    CHAR(3)  NOT NULL ,
	description          varchar(255)  NULL ,
	currency_symbol      varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_iso_currency_code
	ADD CONSTRAINT "pk_val_iso_currency_code" PRIMARY KEY (iso_currency_code);

/***********************************************
 * Table: val_key_usage_reason_for_assignment
 ***********************************************/

CREATE TABLE val_key_usage_reason_for_assignment
( 
	key_usage_reason_for_assignment varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_key_usage_reason_for_assignment
	ADD CONSTRAINT "pk_reason_for_assignment" PRIMARY KEY (key_usage_reason_for_assignment);

/***********************************************
 * Table: val_layer2_network_collection_type
 ***********************************************/

CREATE TABLE val_layer2_network_collection_type
( 
	layer2_network_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_layer2_network_collection_type
	ADD CONSTRAINT "pk_val_layer2_network_coll_typ" PRIMARY KEY (layer2_network_collection_type);

/***********************************************
 * Table: val_layer3_network_collection_type
 ***********************************************/

CREATE TABLE val_layer3_network_collection_type
( 
	layer3_network_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_layer3_network_collection_type
	ADD CONSTRAINT "pk_val_layer3_network_coll_type" PRIMARY KEY (layer3_network_collection_type);

/***********************************************
 * Table: val_logical_port_type
 ***********************************************/

CREATE TABLE val_logical_port_type
( 
	logical_port_type    varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_logical_port_type
	ADD CONSTRAINT "pk_val_logical_port_type" PRIMARY KEY (logical_port_type);

/***********************************************
 * Table: val_logical_volume_property
 ***********************************************/

CREATE TABLE val_logical_volume_property
( 
	logical_volume_property_name varchar(50)  NOT NULL ,
	filesystem_type      character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_logical_volume_property
	ADD CONSTRAINT "pk_val_logical_volume_property" PRIMARY KEY (logical_volume_property_name,filesystem_type);

CREATE INDEX xif_val_lvol_prop_fstype ON val_logical_volume_property
( 
	filesystem_type
);

/***********************************************
 * Table: val_logical_volume_purpose
 ***********************************************/

CREATE TABLE val_logical_volume_purpose
( 
	logical_volume_purpose varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_logical_volume_purpose
	ADD CONSTRAINT "pk_val_logical_volume_purpose" PRIMARY KEY (logical_volume_purpose);

/***********************************************
 * Table: val_logical_volume_type
 ***********************************************/

CREATE TABLE val_logical_volume_type
( 
	logical_volume_type  varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_logical_volume_type
	ADD CONSTRAINT "pk_logical_volume_type" PRIMARY KEY (logical_volume_type);

/***********************************************
 * Table: val_netblock_collection_type
 ***********************************************/

CREATE TABLE val_netblock_collection_type
( 
	netblock_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	netblock_is_single_address_restriction varchar(3)  NOT NULL ,
	netblock_ip_family_restriction integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_netblock_collection_type
	ADD CONSTRAINT "pk_val_netblock_collection_type" PRIMARY KEY (netblock_collection_type);

/***********************************************
 * Table: val_netblock_status
 ***********************************************/

CREATE TABLE val_netblock_status
( 
	netblock_status      varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_netblock_status
	ADD CONSTRAINT "pk_val_netblock_status" PRIMARY KEY (netblock_status);

/***********************************************
 * Table: val_netblock_type
 ***********************************************/

CREATE TABLE val_netblock_type
( 
	netblock_type        varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	db_forced_hierarchy  char(1)  NOT NULL ,
	is_validated_hierarchy char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_netblock_type
	ADD CONSTRAINT "pk_val_netblock_type" PRIMARY KEY (netblock_type);

/***********************************************
 * Table: val_network_interface_purpose
 ***********************************************/

CREATE TABLE val_network_interface_purpose
( 
	network_interface_purpose varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_network_interface_purpose
	ADD CONSTRAINT "pk_val_network_int_purpose" PRIMARY KEY (network_interface_purpose);

/***********************************************
 * Table: val_network_interface_type
 ***********************************************/

CREATE TABLE val_network_interface_type
( 
	network_interface_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_network_interface_type
	ADD CONSTRAINT "pk_network_int_type" PRIMARY KEY (network_interface_type);

/***********************************************
 * Table: val_network_range_type
 ***********************************************/

CREATE TABLE val_network_range_type
( 
	network_range_type   varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	dns_domain_required  char(10)  NOT NULL ,
	default_dns_prefix   varchar(50)  NULL ,
	netblock_type        character varying(50)  NULL ,
	can_overlap          char(1)  NOT NULL ,
	require_cidr_boundary char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_network_range_type
	ADD CONSTRAINT "pk_val_network_range_type" PRIMARY KEY (network_range_type);

CREATE INDEX xif_netrange_type_nb_type ON val_network_range_type
( 
	netblock_type
);

/***********************************************
 * Table: val_network_service_type
 ***********************************************/

CREATE TABLE val_network_service_type
( 
	network_service_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_network_service_type
	ADD CONSTRAINT "pk_network_service_type" PRIMARY KEY (network_service_type);

/***********************************************
 * Table: val_operating_system_family
 ***********************************************/

CREATE TABLE val_operating_system_family
( 
	operating_system_family varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_operating_system_family
	ADD CONSTRAINT "pk_val_operating_system_family" PRIMARY KEY (operating_system_family);

/***********************************************
 * Table: val_operating_system_snapshot_type
 ***********************************************/

CREATE TABLE val_operating_system_snapshot_type
( 
	operating_system_snapshot_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_operating_system_snapshot_type
	ADD CONSTRAINT "pk_val_os_snapshot_type" PRIMARY KEY (operating_system_snapshot_type);

/***********************************************
 * Table: val_ownership_status
 ***********************************************/

CREATE TABLE val_ownership_status
( 
	ownership_status     varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_ownership_status
	ADD CONSTRAINT "pk_val_ownership_status" PRIMARY KEY (ownership_status);

/***********************************************
 * Table: val_package_relation_type
 ***********************************************/

CREATE TABLE val_package_relation_type
( 
	package_relation_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_package_relation_type
	ADD CONSTRAINT "pk_val_package_relation_type" PRIMARY KEY (package_relation_type);

/***********************************************
 * Table: val_password_type
 ***********************************************/

CREATE TABLE val_password_type
( 
	password_type        varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_password_type
	ADD CONSTRAINT "pk_val_password_type" PRIMARY KEY (password_type);

/***********************************************
 * Table: val_person_company_attribute_name
 ***********************************************/

CREATE TABLE val_person_company_attribute_name
( 
	person_company_attribute_name varchar(50)  NOT NULL ,
	person_company_attribute_data_type varchar(50)  NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_company_attribute_name
	ADD CONSTRAINT "pk_val_person_company_attr_name" PRIMARY KEY (person_company_attribute_name);

CREATE INDEX xifprescompattr_name_datatyp ON val_person_company_attribute_name
( 
	person_company_attribute_data_type
);

/***********************************************
 * Table: val_person_company_attribute_value
 ***********************************************/

CREATE TABLE val_person_company_attribute_value
( 
	person_company_attribute_name character varying(50)  NOT NULL ,
	person_company_attribute_value varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_company_attribute_value
	ADD CONSTRAINT "pk_val_pers_company_attr_value" PRIMARY KEY (person_company_attribute_name,person_company_attribute_value);

CREATE INDEX xifpers_comp_attr_val_name ON val_person_company_attribute_value
( 
	person_company_attribute_name
);

/***********************************************
 * Table: val_person_company_attrribute_data_type
 ***********************************************/

CREATE TABLE val_person_company_attrribute_data_type
( 
	person_company_attribute_data_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_company_attrribute_data_type
	ADD CONSTRAINT "pk_val_pers_comp_attr_dataty" PRIMARY KEY (person_company_attribute_data_type);

/***********************************************
 * Table: val_person_company_relation
 ***********************************************/

CREATE TABLE val_person_company_relation
( 
	person_company_relation varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_company_relation
	ADD CONSTRAINT "pk_val_person_company_relation" PRIMARY KEY (person_company_relation);

/***********************************************
 * Table: val_person_contact_location_type
 ***********************************************/

CREATE TABLE val_person_contact_location_type
( 
	person_contact_location_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_contact_location_type
	ADD CONSTRAINT "pk_val_person_contact_loc_type" PRIMARY KEY (person_contact_location_type);

/***********************************************
 * Table: val_person_contact_technology
 ***********************************************/

CREATE TABLE val_person_contact_technology
( 
	person_contact_technology varchar(50)  NOT NULL ,
	person_contact_type  character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_contact_technology
	ADD CONSTRAINT "pk_val_person_contact_technology" PRIMARY KEY (person_contact_technology,person_contact_type);

CREATE INDEX xif1val_person_contact_technology ON val_person_contact_technology
( 
	person_contact_type
);

/***********************************************
 * Table: val_person_contact_type
 ***********************************************/

CREATE TABLE val_person_contact_type
( 
	person_contact_type  varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_contact_type
	ADD CONSTRAINT "pk_val_phone_number_type" PRIMARY KEY (person_contact_type);

/***********************************************
 * Table: val_person_image_usage
 ***********************************************/

CREATE TABLE val_person_image_usage
( 
	person_image_usage   varchar(50)  NOT NULL ,
	is_multivalue        char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_image_usage
	ADD CONSTRAINT "pk_val_person_image_usage" PRIMARY KEY (person_image_usage);

/***********************************************
 * Table: val_person_location_type
 ***********************************************/

CREATE TABLE val_person_location_type
( 
	person_location_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_location_type
	ADD CONSTRAINT "pk_val_user_location_type" PRIMARY KEY (person_location_type);

/***********************************************
 * Table: val_person_status
 ***********************************************/

CREATE TABLE val_person_status
( 
	person_status        varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	is_enabled           char(1)  NOT NULL ,
	propagate_from_person char(1)  NOT NULL ,
	is_forced            char(1)  NOT NULL ,
	is_db_enforced       char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_person_status
	ADD CONSTRAINT "pk_val_person_status" PRIMARY KEY (person_status);

/***********************************************
 * Table: val_physical_address_type
 ***********************************************/

CREATE TABLE val_physical_address_type
( 
	physical_address_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_physical_address_type
	ADD CONSTRAINT "pk_val_physical_address_type" PRIMARY KEY (physical_address_type);

/***********************************************
 * Table: val_physicalish_volume_type
 ***********************************************/

CREATE TABLE val_physicalish_volume_type
( 
	physicalish_volume_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_physicalish_volume_type
	ADD CONSTRAINT "pk_val_physicalish_volume_type" PRIMARY KEY (physicalish_volume_type);

/***********************************************
 * Table: val_private_key_encryption_type
 ***********************************************/

CREATE TABLE val_private_key_encryption_type
( 
	private_key_encryption_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_private_key_encryption_type
	ADD CONSTRAINT "pk_val_pvt_key_encryption_type" PRIMARY KEY (private_key_encryption_type);

/***********************************************
 * Table: val_processor_architecture
 ***********************************************/

CREATE TABLE val_processor_architecture
( 
	processor_architecture varchar(50)  NOT NULL ,
	kernel_bits          integer  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_processor_architecture
	ADD CONSTRAINT "pk_val_processor_architecture" PRIMARY KEY (processor_architecture);

/***********************************************
 * Table: val_production_state
 ***********************************************/

CREATE TABLE val_production_state
( 
	production_state     varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_production_state
	ADD CONSTRAINT "pk_val_production_state" PRIMARY KEY (production_state);

/***********************************************
 * Table: val_property
 ***********************************************/

CREATE TABLE val_property
( 
	property_name        varchar(255)  NOT NULL ,
	property_type        varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	account_collection_type character varying(50)  NULL ,
	company_collection_type varchar(50)  NULL ,
	device_collection_type character varying(50)  NULL ,
	dns_domain_collection_type varchar(50)  NULL ,
	layer2_network_collection_type varchar(50)  NULL ,
	layer3_network_collection_type varchar(50)  NULL ,
	netblock_collection_type varchar(50)  NULL ,
	network_range_type   varchar(50)  NULL ,
	property_name_collection_type varchar(50)  NULL ,
	service_environment_collection_type varchar(50)  NULL ,
	is_multivalue        CHAR(1)  NOT NULL ,
	property_value_account_collection_type_restriction character varying(50)  NULL ,
	property_value_device_collection_type_restriction character varying(50)  NULL ,
	property_value_netblock_collection_type_restriction varchar(50)  NULL ,
	property_data_type   varchar(50)  NOT NULL ,
	property_value_json_schema jsonb  NULL ,
	permit_account_collection_id CHAR(10)  NOT NULL ,
	permit_account_id    CHAR(10)  NOT NULL ,
	permit_account_realm_id char(10)  NOT NULL ,
	permit_company_id    CHAR(10)  NOT NULL ,
	permit_company_collection_id char(10)  NOT NULL ,
	permit_device_collection_id CHAR(10)  NOT NULL ,
	permit_dns_domain_collection_id char(10)  NOT NULL ,
	permit_layer2_network_collection_id char(10)  NOT NULL ,
	permit_layer3_network_collection_id char(10)  NOT NULL ,
	permit_netblock_collection_id char(10)  NOT NULL ,
	permit_network_range_id char(10)  NOT NULL ,
	permit_operating_system_id char(10)  NOT NULL ,
	permit_operating_system_snapshot_id char(10)  NOT NULL ,
	permit_person_id     char(10)  NOT NULL ,
	permit_property_collection_id char(10)  NOT NULL ,
	permit_service_environment_collection char(10)  NOT NULL ,
	permit_site_code     CHAR(10)  NOT NULL ,
	permit_x509_signed_certificate_id char(10)  NOT NULL ,
	permit_property_rank char(10)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_property
	ADD CONSTRAINT "pk_val_property" PRIMARY KEY (property_name,property_type);

CREATE INDEX xif3val_property ON val_property
( 
	property_value_account_collection_type_restriction
);

CREATE INDEX xif4val_property ON val_property
( 
	property_value_netblock_collection_type_restriction
);

CREATE INDEX xif5val_property ON val_property
( 
	property_value_device_collection_type_restriction
);

CREATE INDEX xif6val_property ON val_property
( 
	account_collection_type
);

CREATE INDEX xif7val_property ON val_property
( 
	company_collection_type
);

CREATE INDEX xif8val_property ON val_property
( 
	device_collection_type
);

CREATE INDEX xif9val_property ON val_property
( 
	dns_domain_collection_type
);

CREATE INDEX xif10val_property ON val_property
( 
	netblock_collection_type
);

CREATE INDEX xif11val_property ON val_property
( 
	property_name_collection_type
);

CREATE INDEX xif12val_property ON val_property
( 
	service_environment_collection_type
);

CREATE INDEX xif13val_property ON val_property
( 
	layer3_network_collection_type
);

CREATE INDEX xif14val_property ON val_property
( 
	layer2_network_collection_type
);

CREATE INDEX xif15val_property ON val_property
( 
	network_range_type
);

CREATE INDEX xif1val_property ON val_property
( 
	property_data_type
);

CREATE INDEX xif2val_property ON val_property
( 
	property_type
);

/***********************************************
 * Table: val_property_data_type
 ***********************************************/

CREATE TABLE val_property_data_type
( 
	property_data_type   varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_property_data_type
	ADD CONSTRAINT "pk_val_property_data_type" PRIMARY KEY (property_data_type);

/***********************************************
 * Table: val_property_name_collection_type
 ***********************************************/

CREATE TABLE val_property_name_collection_type
( 
	property_name_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_property_name_collection_type
	ADD CONSTRAINT "pk_property_collction_type" PRIMARY KEY (property_name_collection_type);

/***********************************************
 * Table: val_property_type
 ***********************************************/

CREATE TABLE val_property_type
( 
	property_type        varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	property_value_account_collection_type_restriction character varying(50)  NULL ,
	is_multivalue        CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_property_type
	ADD CONSTRAINT "pk_val_property_type" PRIMARY KEY (property_type);

CREATE INDEX xif1val_property_type ON val_property_type
( 
	property_value_account_collection_type_restriction
);

CREATE TABLE val_property_value
( 
	property_name        character varying(255)  NOT NULL ,
	property_type        character varying(50)  NOT NULL ,
	valid_property_value varchar(255)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_property_value
	ADD CONSTRAINT "pk_val_property_vaue" PRIMARY KEY (property_name,property_type,valid_property_value);

CREATE INDEX xifvalproval_namtyp ON val_property_value
( 
	property_name,
	property_type
);

/***********************************************
 * Table: val_rack_type
 ***********************************************/

CREATE TABLE val_rack_type
( 
	rack_type            varchar(255)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_rack_type
	ADD CONSTRAINT "pk_val_rack_type" PRIMARY KEY (rack_type);

/***********************************************
 * Table: val_raid_type
 ***********************************************/

CREATE TABLE val_raid_type
( 
	raid_type            varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	primary_raid_level   integer  NULL ,
	secondary_raid_level integer  NULL ,
	raid_level_qualifier integer  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_raid_type
	ADD CONSTRAINT "pk_raid_type" PRIMARY KEY (raid_type);

/***********************************************
 * Table: val_service_environment_collection_type
 ***********************************************/

CREATE TABLE val_service_environment_collection_type
( 
	service_env_collection_type varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_service_environment_collection_type
	ADD CONSTRAINT "pk_val_service_env_coll_type" PRIMARY KEY (service_env_collection_type);

/***********************************************
 * Table: val_shared_netblock_protocol
 ***********************************************/

CREATE TABLE val_shared_netblock_protocol
( 
	shared_netblock_protocol varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_shared_netblock_protocol
	ADD CONSTRAINT "pk_val_shared_netblock_protocol" PRIMARY KEY (shared_netblock_protocol);

/***********************************************
 * Table: val_slot_function
 ***********************************************/

CREATE TABLE val_slot_function
( 
	slot_function        varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	can_have_mac_address char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_slot_function
	ADD CONSTRAINT "pk_val_slot_function" PRIMARY KEY (slot_function);

/***********************************************
 * Table: val_slot_physical_interface
 ***********************************************/

CREATE TABLE val_slot_physical_interface
( 
	slot_physical_interface_type varchar(50)  NOT NULL ,
	slot_function        character varying(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_slot_physical_interface
	ADD CONSTRAINT "pk_val_slot_physical_interface" PRIMARY KEY (slot_physical_interface_type,slot_function);

CREATE INDEX xif_slot_phys_int_slot_func ON val_slot_physical_interface
( 
	slot_function
);

/***********************************************
 * Table: val_ssh_key_type
 ***********************************************/

CREATE TABLE val_ssh_key_type
( 
	ssh_key_type         varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_ssh_key_type
	ADD CONSTRAINT "pk_val_ssh_key_type" PRIMARY KEY (ssh_key_type);

/***********************************************
 * Table: val_sw_package_type
 ***********************************************/

CREATE TABLE val_sw_package_type
( 
	sw_package_type      varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_sw_package_type
	ADD CONSTRAINT "pk_val_sw_package_type" PRIMARY KEY (sw_package_type);

/***********************************************
 * Table: val_token_collection_type
 ***********************************************/

CREATE TABLE val_token_collection_type
( 
	token_collection_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	max_num_members      integer  NULL ,
	max_num_collections  integer  NULL ,
	can_have_hierarchy   char(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_token_collection_type
	ADD CONSTRAINT "pk_val_token_collection_type" PRIMARY KEY (token_collection_type);

/***********************************************
 * Table: val_token_status
 ***********************************************/

CREATE TABLE val_token_status
( 
	token_status         varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_token_status
	ADD CONSTRAINT "pk_val_token_status" PRIMARY KEY (token_status);

/***********************************************
 * Table: val_token_type
 ***********************************************/

CREATE TABLE val_token_type
( 
	token_type           varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	token_digit_count    integer  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_token_type
	ADD CONSTRAINT "pk_val_token_type" PRIMARY KEY (token_type);

/***********************************************
 * Table: val_volume_group_purpose
 ***********************************************/

CREATE TABLE val_volume_group_purpose
( 
	volume_group_purpose varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_volume_group_purpose
	ADD CONSTRAINT "pk_val_volume_group_purpose" PRIMARY KEY (volume_group_purpose);

/***********************************************
 * Table: val_volume_group_relation
 ***********************************************/

CREATE TABLE val_volume_group_relation
( 
	volume_group_relation varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_volume_group_relation
	ADD CONSTRAINT "pk_val_volume_group_relation" PRIMARY KEY (volume_group_relation);

/***********************************************
 * Table: val_volume_group_type
 ***********************************************/

CREATE TABLE val_volume_group_type
( 
	volume_group_type    varchar(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_volume_group_type
	ADD CONSTRAINT "pk_volume_group_type" PRIMARY KEY (volume_group_type);

/***********************************************
 * Table: val_x509_certificate_file_format
 ***********************************************/

CREATE TABLE val_x509_certificate_file_format
( 
	x509_certificate_file_format varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_x509_certificate_file_format
	ADD CONSTRAINT "pk_certificate_file_format" PRIMARY KEY (x509_certificate_file_format);

/***********************************************
 * Table: val_x509_certificate_type
 ***********************************************/

CREATE TABLE val_x509_certificate_type
( 
	x509_certificate_type varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_x509_certificate_type
	ADD CONSTRAINT "pk_x509_certificate_type" PRIMARY KEY (x509_certificate_type);

/***********************************************
 * Table: val_x509_key_usage
 ***********************************************/

CREATE TABLE val_x509_key_usage
( 
	x509_key_usage       varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	is_extended          CHAR(1)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_x509_key_usage
	ADD CONSTRAINT "pk_x509_key_usage" PRIMARY KEY (x509_key_usage);

/***********************************************
 * Table: val_x509_key_usage_category
 ***********************************************/

CREATE TABLE val_x509_key_usage_category
( 
	x509_key_usage_category varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_x509_key_usage_category
	ADD CONSTRAINT "pk_x509_key_usage_category" PRIMARY KEY (x509_key_usage_category);

/***********************************************
 * Table: val_x509_revocation_reason
 ***********************************************/

CREATE TABLE val_x509_revocation_reason
( 
	x509_revocation_reason varchar(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE val_x509_revocation_reason
	ADD CONSTRAINT "pk_val_x509_revocation_reason" PRIMARY KEY (x509_revocation_reason);

/***********************************************
 * Table: volume_group
 ***********************************************/

CREATE TABLE volume_group
( 
	volume_group_id      serial  NOT NULL ,
	device_id            integer  NULL ,
	component_id         integer  NULL ,
	volume_group_name    varchar(50)  NOT NULL ,
	volume_group_type    varchar(50)  NULL ,
	volume_group_size_in_bytes bigint  NOT NULL ,
	raid_type            varchar(50)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE volume_group
	ADD CONSTRAINT "pk_volume_group" PRIMARY KEY (volume_group_id);

ALTER TABLE volume_group
	ADD CONSTRAINT "ak_volume_group_devid_vgid" UNIQUE (volume_group_id,device_id);

ALTER TABLE volume_group
	ADD CONSTRAINT "ak_volume_group_vg_devid" UNIQUE (volume_group_id,device_id);

ALTER TABLE volume_group
	ADD CONSTRAINT "uq_volgrp_devid_name_type" UNIQUE (device_id,component_id,volume_group_name,volume_group_type);

CREATE INDEX xif5volume_group ON volume_group
( 
	component_id
);

CREATE INDEX xif_volgrp_devid ON volume_group
( 
	device_id
);

CREATE INDEX xif_volgrp_rd_type ON volume_group
( 
	raid_type
);

CREATE INDEX xif_volgrp_volgrp_type ON volume_group
( 
	volume_group_type
);

CREATE INDEX xi_volume_group_name ON volume_group
( 
	volume_group_name
);

/***********************************************
 * Table: volume_group_physicalish_vol
 ***********************************************/

CREATE TABLE volume_group_physicalish_vol
( 
	physicalish_volume_id integer  NOT NULL ,
	volume_group_id      integer  NOT NULL ,
	device_id            integer  NULL ,
	volume_group_primary_position integer  NULL ,
	volume_group_secondary_position integer  NULL ,
	volume_group_relation varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "pk_volume_group_physicalish_vol" PRIMARY KEY (physicalish_volume_id,volume_group_id);

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "uq_volgrp_pv_position" UNIQUE (volume_group_id,volume_group_primary_position)
	DEFERRABLE  ;

CREATE INDEX xif_physvol_vg_phsvol_dvid ON volume_group_physicalish_vol
( 
	physicalish_volume_id,
	device_id
);

CREATE INDEX xif_vgp_phy_phyid ON volume_group_physicalish_vol
( 
	physicalish_volume_id
);

CREATE INDEX xif_vgp_phy_vgrpid ON volume_group_physicalish_vol
( 
	volume_group_id
);

CREATE INDEX xif_vgp_phy_vgrpid_devid ON volume_group_physicalish_vol
( 
	device_id,
	volume_group_id
);

CREATE INDEX xif_vg_physvol_vgrel ON volume_group_physicalish_vol
( 
	volume_group_relation
);

CREATE INDEX xiq_volgrp_pv_position ON volume_group_physicalish_vol
( 
	volume_group_id ASC,
	volume_group_primary_position ASC
);

/***********************************************
 * Table: volume_group_purpose
 ***********************************************/

CREATE TABLE volume_group_purpose
( 
	volume_group_id      integer  NOT NULL ,
	volume_group_purpose character varying(50)  NOT NULL ,
	description          varchar(4000)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE volume_group_purpose
	ADD CONSTRAINT "pk_volume_group_purpose" PRIMARY KEY (volume_group_id,volume_group_purpose);

CREATE INDEX xif_val_volgrp_purp_vgid ON volume_group_purpose
( 
	volume_group_id
);

CREATE INDEX xif_val_volgrp_purp_vgpurp ON volume_group_purpose
( 
	volume_group_purpose
);

/***********************************************
 * Table: x509_key_usage_attribute
 ***********************************************/

CREATE TABLE x509_key_usage_attribute
( 
	x509_signed_certificate_id integer  NOT NULL ,
	x509_key_usage       character varying(50)  NOT NULL ,
	x509_key_usgage_category varchar(50)  NOT NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT "pk_key_usage_attribute" PRIMARY KEY (x509_signed_certificate_id,x509_key_usage);

/***********************************************
 * Table: x509_key_usage_categorization
 ***********************************************/

CREATE TABLE x509_key_usage_categorization
( 
	x509_key_usage_category character varying(50)  NOT NULL ,
	x509_key_usage       character varying(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE x509_key_usage_categorization
	ADD CONSTRAINT "pk_key_usage_cat" PRIMARY KEY (x509_key_usage_category,x509_key_usage);

/***********************************************
 * Table: x509_key_usage_default
 ***********************************************/

CREATE TABLE x509_key_usage_default
( 
	x509_signed_certificate_id integer  NOT NULL ,
	x509_key_usage       character varying(50)  NOT NULL ,
	description          varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE x509_key_usage_default
	ADD CONSTRAINT "pk_x509_key_usage_default" PRIMARY KEY (x509_signed_certificate_id,x509_key_usage);

CREATE INDEX xif2x509_key_usage_default ON x509_key_usage_default
( 
	x509_key_usage
);

CREATE INDEX fk_x509keyusgdef_signcertid ON x509_key_usage_default
( 
	x509_signed_certificate_id
);

/***********************************************
 * Table: x509_signed_certificate
 ***********************************************/

CREATE TABLE x509_signed_certificate
( 
	x509_signed_certificate_id serial  NOT NULL ,
	x509_certificate_type varchar(50)  NULL ,
	subject              varchar(255)  NOT NULL ,
	friendly_name        varchar(255)  NOT NULL ,
	subject_key_identifier varchar(255)  NULL ,
	is_active            char(1)  NOT NULL ,
	is_certificate_authority char(1)  NOT NULL ,
	signing_cert_id      integer  NULL ,
	x509_ca_cert_serial_number numeric  NULL ,
	public_key           text  NULL ,
	private_key_id       integer  NULL ,
	certificate_signing_request_id integer  NULL ,
	valid_from           timestamp without time zone  NOT NULL ,
	valid_to             timestamp without time zone  NOT NULL ,
	x509_revocation_date timestamp with time zone  NULL ,
	x509_revocation_reason varchar(50)  NULL ,
	ocsp_uri             varchar(255)  NULL ,
	crl_uri              varchar(255)  NULL ,
	data_ins_user        varchar(255)  NULL ,
	data_ins_date        timestamp with time zone  NULL ,
	data_upd_user        varchar(255)  NULL ,
	data_upd_date        timestamp with time zone  NULL 
);

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "pk_x509_certificate" PRIMARY KEY (x509_signed_certificate_id);

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "ak_x509_cert_cert_ca_ser" UNIQUE (signing_cert_id,x509_ca_cert_serial_number);

CREATE INDEX xif3x509_signed_certificate ON x509_signed_certificate
( 
	x509_revocation_reason
);

CREATE INDEX xif4x509_signed_certificate ON x509_signed_certificate
( 
	private_key_id
);

CREATE INDEX xif5x509_signed_certificate ON x509_signed_certificate
( 
	certificate_signing_request_id
);

CREATE INDEX xif6x509_signed_certificate ON x509_signed_certificate
( 
	x509_certificate_type
);


ALTER TABLE account
	ADD CONSTRAINT check_yes_no_707724729 CHECK  ( is_enabled IN ('Y', 'N') ) ;


ALTER TABLE account
	ADD CONSTRAINT "fk_account_acct_rlm_id" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account
	ADD CONSTRAINT "fk_account_acctrole" FOREIGN KEY (account_role) REFERENCES val_account_role(account_role)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account
	ADD CONSTRAINT "fk_account_company_person" FOREIGN KEY (company_id,person_id) REFERENCES person_company(company_id,person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE account
	ADD CONSTRAINT "fk_account_prsn_cmpy_acct" FOREIGN KEY (person_id,company_id,account_realm_id) REFERENCES person_account_realm_company(person_id,company_id,account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE account
	ADD CONSTRAINT "fk_acct_stat_id" FOREIGN KEY (account_status) REFERENCES val_person_status(person_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account
	ADD CONSTRAINT "fk_acct_vacct_type" FOREIGN KEY (account_type) REFERENCES val_account_type(account_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN account.is_enabled IS 'This column is trigger enforced to match what val_person_status says is the correct value for account_status';

COMMENT ON COLUMN account.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE account_assigned_certificate
	ADD CONSTRAINT "fk_x509_key_usg_attrbt_usr" FOREIGN KEY (x509_cert_id,x509_key_usg) REFERENCES x509_key_usage_attribute(x509_signed_certificate_id,x509_key_usage)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_assigned_certificate
	ADD CONSTRAINT "fk_key_usg_reason_for_assgn_u" FOREIGN KEY (key_usage_reason_for_assign) REFERENCES val_key_usage_reason_for_assignment(key_usage_reason_for_assignment)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_assigned_certificate
	ADD CONSTRAINT "fk_acct_asdcrt_acctid" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE account_assigned_certificate IS 'Actual  assignment of the usage category USER Certificates to System Users.';

COMMENT ON COLUMN account_assigned_certificate.x509_key_usg IS 'Name of the Certificate.';

COMMENT ON COLUMN account_assigned_certificate.x509_cert_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN account_assigned_certificate.key_usage_reason_for_assign IS 'Uniquely identifies and indicates reason for assignment.';


ALTER TABLE account_auth_log
	ADD CONSTRAINT check_yes_no_1972033909 CHECK  ( was_auth_success IN ('Y', 'N') ) ;


ALTER TABLE account_auth_log
	ADD CONSTRAINT "fk_acctauthlog_accid" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_auth_log
	ADD CONSTRAINT "fk_auth_resource" FOREIGN KEY (auth_resource) REFERENCES val_auth_resource(auth_resource)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE account_auth_log IS 'Captures all system user authorizations for access to Vonage resources.';

COMMENT ON COLUMN account_auth_log.account_auth_seq IS 'This sequence is to support table PK with timestamps recived rounded to the secend and generating duplicates.';

COMMENT ON COLUMN account_auth_log.auth_resource_instance IS 'Keeps track of the server where a user was authenticating for a given resource';

COMMENT ON COLUMN account_auth_log.auth_origin IS 'Keeps track of where the request for authentication originated from.';


ALTER TABLE account_collection
	ADD CONSTRAINT "fk_acctcol_usrcoltyp" FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN account_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';

ALTER TABLE account_collection_account
	ALTER COLUMN account_collection_relation
		SET DEFAULT 'direct';


ALTER TABLE account_collection_account
	ADD CONSTRAINT "fk_acctcollacct_ac_relate" FOREIGN KEY (account_collection_relation) REFERENCES val_account_collection_relation(account_collection_relation)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_collection_account
	ADD CONSTRAINT "fk_acol_account_id" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_collection_account
	ADD CONSTRAINT "fk_acctcol_usr_ucol_id" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE account_collection_hier
	ADD CONSTRAINT "fk_acctcolhier_acctcolid" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_collection_hier
	ADD CONSTRAINT "fk_acctcolhier_cldacctcolid" FOREIGN KEY (child_account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE account_collection_type_relation
	ADD CONSTRAINT "fk_acct_coll_rel_type_rel" FOREIGN KEY (account_collection_relation) REFERENCES val_account_collection_relation(account_collection_relation)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_collection_type_relation
	ADD CONSTRAINT "fk_acct_coll_rel_type_type" FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE account_collection_type_relation IS 'Defines types of account collection relations that are permitted for a given account collection type.  This is trigger enforced, and ''direct'' is added here as part of an insert trigger on val_account_collection_type.';


ALTER TABLE account_password
	ADD CONSTRAINT "fk_acctpwd_acct_id" FOREIGN KEY (account_id,account_realm_id) REFERENCES account(account_id,account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_password
	ADD CONSTRAINT "fk_acct_pass_ref_vpasstype" FOREIGN KEY (password_type) REFERENCES val_password_type(password_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_password
	ADD CONSTRAINT "fk_acct_pwd_acct_realm" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_password
	ADD CONSTRAINT "fk_acct_pwd_realm_type" FOREIGN KEY (password_type,account_realm_id) REFERENCES account_realm_password_type(password_type,account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN account_password.change_time IS 'The last thie this password was changed';

COMMENT ON COLUMN account_password.expire_time IS 'The time this password expires, if different from the default';

COMMENT ON COLUMN account_password.unlock_time IS 'indicates the time that the password is unlocked and can thus be changed; NULL means the password can be changed.  This is application enforced.';

COMMENT ON COLUMN account_password.account_realm_id IS 'Set to allow enforcement of password type/account_realm_id.   Largely managed in the background by trigger';


ALTER TABLE account_realm_account_collection_type
	ADD CONSTRAINT "fk_acct_realm_acct_coll_typ" FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_realm_account_collection_type
	ADD CONSTRAINT "fk_acct_realm_acct_coll_arid" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE account_realm_company
	ADD CONSTRAINT "fk_acct_rlm_cmpy_cmpy_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE account_realm_company
	ADD CONSTRAINT "fk_acct_rlm_cmpy_actrlmid" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE account_realm_password_type
	ADD CONSTRAINT "fk_acrlm_acct_rlm_id" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_realm_password_type
	ADD CONSTRAINT "fk_acrlm_pwd_type" FOREIGN KEY (password_type) REFERENCES val_password_type(password_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE account_ssh_key
	ADD CONSTRAINT "fk_account_ssh_key_account_id" FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_ssh_key
	ADD CONSTRAINT "fk_account_ssh_key_ssh_key_id" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE account_token
	ADD CONSTRAINT "fk_acct_token_ref_token" FOREIGN KEY (token_id) REFERENCES token(token_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_token
	ADD CONSTRAINT "fk_acct_ref_acct_token" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN account_token.account_token_id IS 'This is its own PK in order to better handle auditing.';


ALTER TABLE account_unix_info
	ADD CONSTRAINT "fk_auxifo_unxgrp_acctcolid" FOREIGN KEY (unix_group_account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_unix_info
	ADD CONSTRAINT "fk_acct_unx_info_ac_acct" FOREIGN KEY (unix_group_account_collection_id,account_id) REFERENCES account_collection_account(account_collection_id,account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE account_unix_info
	ADD CONSTRAINT "fk_auxifo_acct_id" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE appaal_instance
	ADD CONSTRAINT ckc_file_mode_appaal_i CHECK  ( FILE_MODE between 0 and 4095 ) ;


ALTER TABLE appaal_instance
	ADD CONSTRAINT "fk_appaal_i_fk_applic_svcenv" FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance
	ADD CONSTRAINT "fk_appaal_ref_appaal_inst" FOREIGN KEY (appaal_id) REFERENCES appaal(appaal_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance
	ADD CONSTRAINT "fk_appaal_i_reference_fo_acctid" FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance
	ADD CONSTRAINT "fk_appaal_inst_filgrpacctcolid" FOREIGN KEY (file_group_account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE appaal_instance_device_collection
	ADD CONSTRAINT "fk_appaalins_ref_appaalinsdcol" FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance_device_collection
	ADD CONSTRAINT "fk_devcoll_ref_appaalinstdcoll" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE appaal_instance_property
	ADD CONSTRAINT "fk_appaalinstprop_ref_vappkey" FOREIGN KEY (appaal_group_name,app_key) REFERENCES val_app_key(appaal_group_name,app_key)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance_property
	ADD CONSTRAINT "fk_appaalins_ref_appaalinsprop" FOREIGN KEY (appaal_instance_id) REFERENCES appaal_instance(appaal_instance_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance_property
	ADD CONSTRAINT "fk_apalinstprp_enc_id_id" FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE appaal_instance_property
	ADD CONSTRAINT "fk_allgrpprop_val_name" FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN appaal_instance_property.encryption_key_id IS 'encryption information for app_value, if used';

ALTER TABLE approval_instance
	ALTER COLUMN approval_start
		SET DEFAULT now();


ALTER TABLE approval_instance
	ADD CONSTRAINT "fk_approval_proc_inst_aproc_id" FOREIGN KEY (approval_process_id) REFERENCES approval_process(approval_process_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE approval_instance_item
	ADD CONSTRAINT check_yes_no_1852849955 CHECK  ( is_approved IN ('Y', 'N') ) ;


ALTER TABLE approval_instance_item
	ADD CONSTRAINT "fk_appinstitem_appinststep" FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_item
	ADD CONSTRAINT "fk_app_inst_item_appinstlinkid" FOREIGN KEY (approval_instance_link_id) REFERENCES approval_instance_link(approval_instance_link_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_item
	ADD CONSTRAINT "fk_appinstitmid_nextapiiid" FOREIGN KEY (next_approval_instance_item_id) REFERENCES approval_instance_item(approval_instance_item_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_item
	ADD CONSTRAINT "fk_appinstitm_app_acctid" FOREIGN KEY (approved_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE approval_instance_step
	ADD CONSTRAINT check_yes_no_1566117395 CHECK  ( is_completed IN ('Y', 'N') ) ;

ALTER TABLE approval_instance_step
	ALTER COLUMN approval_instance_step_start
		SET DEFAULT now();

ALTER TABLE approval_instance_step
	ALTER COLUMN is_completed
		SET DEFAULT 'N';


ALTER TABLE approval_instance_step
	ADD CONSTRAINT "fk_app_inst_step_apinstid" FOREIGN KEY (approval_instance_id) REFERENCES approval_instance(approval_instance_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_step
	ADD CONSTRAINT "fk_appinststep_app_type" FOREIGN KEY (approval_type) REFERENCES val_approval_type(approval_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_step
	ADD CONSTRAINT "fk_appinststep_app_prcchnid" FOREIGN KEY (approval_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_step
	ADD CONSTRAINT "fk_appinststep_app_acct_id" FOREIGN KEY (approver_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT "fk_appinststepntfy_ntfy_typ" FOREIGN KEY (approval_notify_type) REFERENCES val_approval_notifty_type(approval_notify_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT "fk_appinststep_appinstprocid" FOREIGN KEY (approval_instance_step_id) REFERENCES approval_instance_step(approval_instance_step_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_instance_step_notify
	ADD CONSTRAINT "fk_appr_inst_step_notif_acct" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE approval_process
	ADD CONSTRAINT "fk_app_prc_propcoll_id" FOREIGN KEY (property_name_collection_id) REFERENCES property_name_collection(property_name_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_process
	ADD CONSTRAINT "fk_app_proc_app_proc_typ" FOREIGN KEY (approval_process_type) REFERENCES val_approval_process_type(approval_process_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_process
	ADD CONSTRAINT "fk_app_proc_expire_action" FOREIGN KEY (approval_expiration_action) REFERENCES val_approval_expiration_action(approval_expiration_action)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_process
	ADD CONSTRAINT "fk_appproc_attest_freq" FOREIGN KEY (attestation_frequency) REFERENCES val_attestation_frequency(attestation_frequency)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_process
	ADD CONSTRAINT "fk_app_proc_1st_app_proc_chnid" FOREIGN KEY (first_approval_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE approval_process_chain
	ADD CONSTRAINT check_yes_no_960168 CHECK  ( refresh_all_data IN ('Y', 'N') ) ;

ALTER TABLE approval_process_chain
	ALTER COLUMN approval_chain_response_period
		SET DEFAULT '1 week';

ALTER TABLE approval_process_chain
	ALTER COLUMN refresh_all_data
		SET DEFAULT 'N';


ALTER TABLE approval_process_chain
	ADD CONSTRAINT "fk_appproc_chn_resp_period" FOREIGN KEY (approval_chain_response_period) REFERENCES val_approval_chain_response_period(approval_chain_response_period)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_process_chain
	ADD CONSTRAINT "fk_apprchn_rej_proc_chn" FOREIGN KEY (accept_app_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE approval_process_chain
	ADD CONSTRAINT "fk_apprchn_app_proc_chn" FOREIGN KEY (accept_app_process_chain_id) REFERENCES approval_process_chain(approval_process_chain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE asset
	ADD CONSTRAINT "fk_asset_comp_id" FOREIGN KEY (component_id) REFERENCES component(component_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE asset
	ADD CONSTRAINT "fk_asset_contract_id" FOREIGN KEY (contract_id) REFERENCES contract(contract_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE asset
	ADD CONSTRAINT "fk_asset_ownshp_stat" FOREIGN KEY (ownership_status) REFERENCES val_ownership_status(ownership_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE badge
	ADD CONSTRAINT "fk_badge_badge_type" FOREIGN KEY (badge_type_id) REFERENCES badge_type(badge_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE badge
	ADD CONSTRAINT "fk_badge_vbadgestatus" FOREIGN KEY (badge_status) REFERENCES val_badge_status(badge_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE certificate_signing_request
	ADD CONSTRAINT "fk_pvtkey_csr" FOREIGN KEY (private_key_id) REFERENCES private_key(private_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE certificate_signing_request IS 'Certificiate Signing Requests generated from public key.  This is mostly kept for posterity since its possible to generate these at-wil from the private key.';

COMMENT ON COLUMN certificate_signing_request.certificate_signing_request_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN certificate_signing_request.certificate_signing_request IS 'Textual representation of a certificate signing certificate';

COMMENT ON COLUMN certificate_signing_request.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';

COMMENT ON COLUMN certificate_signing_request.friendly_name IS 'human readable name for certificate.  often just the CN.';

COMMENT ON COLUMN certificate_signing_request.private_key_id IS '
';


ALTER TABLE chassis_location
	ADD CONSTRAINT "fk_chas_loc_dt_module" FOREIGN KEY (chassis_device_type_id,device_type_module_name) REFERENCES device_type_module(device_type_id,device_type_module_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE chassis_location
	ADD CONSTRAINT "fk_chass_loc_mod_dev_typ_id" FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE chassis_location
	ADD CONSTRAINT "fk_chass_loc_chass_devid" FOREIGN KEY (chassis_device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE chassis_location
	ADD CONSTRAINT "fk_dtyp_mod_dev_chass_location" FOREIGN KEY (module_device_type_id,chassis_device_type_id,device_type_module_name) REFERENCES device_type_module_device_type(module_device_type_id,device_type_id,device_type_module_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN chassis_location.chassis_device_type_id IS 'Device Type of the Container Device (Chassis)';

COMMENT ON COLUMN chassis_location.device_type_module_name IS 'Name used to describe the module programatically.';


ALTER TABLE circuit
	ADD CONSTRAINT check_yes_no_1766081229 CHECK  ( is_locally_managed IN ('Y', 'N') ) ;


ALTER TABLE circuit
	ADD CONSTRAINT "fk_circuit_vend_companyid" FOREIGN KEY (vendor_company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE circuit
	ADD CONSTRAINT "fk_circuit_aloc_companyid" FOREIGN KEY (aloc_lec_company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE circuit
	ADD CONSTRAINT "fk_circuit_zloc_company_id" FOREIGN KEY (zloc_lec_company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE circuit
	ADD CONSTRAINT "fk_circuit_ref_end1circuit" FOREIGN KEY (aloc_parent_circuit_id) REFERENCES circuit(circuit_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE circuit
	ADD CONSTRAINT "fk_circuit_ref_end2circuit" FOREIGN KEY (zloc_parent_circuit_id) REFERENCES circuit(circuit_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE company
	ADD CONSTRAINT ckc_cmpy_shrt_name_897362587 CHECK  ( company_short_name = lower(company_short_name) and company_short_name not like '% %' ) ;


ALTER TABLE company
	ADD CONSTRAINT "fk_company_parent_company_id" FOREIGN KEY (parent_company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

COMMENT ON COLUMN company.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE company_collection
	ADD CONSTRAINT "fk_comp_coll_com_coll_type" FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN company_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE company_collection_company
	ADD CONSTRAINT "fk_company_coll_company_coll_i" FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE company_collection_company
	ADD CONSTRAINT "fk_company_coll_company_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE company_collection_hier
	ADD CONSTRAINT "fk_comp_coll_comp_coll_id" FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE company_collection_hier
	ADD CONSTRAINT "fk_comp_coll_comp_coll_kid_id" FOREIGN KEY (child_company_collection_id) REFERENCES company_collection(company_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE company_type
	ADD CONSTRAINT "fk_company_type_company_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE company_type
	ADD CONSTRAINT "fk_company_type_val" FOREIGN KEY (company_type) REFERENCES val_company_type(company_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE component
	ADD CONSTRAINT "fk_component_comp_type_i" FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component
	ADD CONSTRAINT "fk_component_prnt_slt_id" FOREIGN KEY (parent_slot_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component
	ADD CONSTRAINT "fk_component_rack_loc_id" FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_int_cmp_conn_id" FOREIGN KEY (inter_component_connection_id) REFERENCES inter_component_connection(inter_component_connection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_cmp_id" FOREIGN KEY (component_id) REFERENCES component(component_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_comp_func" FOREIGN KEY (component_function) REFERENCES val_component_function(component_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_comp_typ_id" FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_prop_nmty" FOREIGN KEY (component_property_name,component_property_type) REFERENCES val_component_property(component_property_name,component_property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_sltfuncid" FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_slt_slt_id" FOREIGN KEY (slot_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_property
	ADD CONSTRAINT "fk_comp_prop_slt_typ_id" FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE component_type
	ADD CONSTRAINT check_yes_no_1178386392 CHECK  ( is_removable IN ('Y', 'N') ) ;

ALTER TABLE component_type
	ADD CONSTRAINT check_yes_no_606817185 CHECK  ( asset_permitted IN ('Y', 'N') ) ;

ALTER TABLE component_type
	ADD CONSTRAINT check_yes_no_1115790481 CHECK  ( is_rack_mountable IN ('Y', 'N') ) ;

ALTER TABLE component_type
	ADD CONSTRAINT check_yes_no_1683679475 CHECK  ( is_virtual_component IN ('Y', 'N') ) ;

ALTER TABLE component_type
	ALTER COLUMN is_removable
		SET DEFAULT 'N';

ALTER TABLE component_type
	ALTER COLUMN size_units
		SET DEFAULT 0;

ALTER TABLE component_type
	ALTER COLUMN asset_permitted
		SET DEFAULT 'N';

ALTER TABLE component_type
	ALTER COLUMN is_rack_mountable
		SET DEFAULT 'N';

ALTER TABLE component_type
	ALTER COLUMN is_virtual_component
		SET DEFAULT 'N';


ALTER TABLE component_type
	ADD CONSTRAINT "fk_component_type_company_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_type
	ADD CONSTRAINT "fk_component_type_slt_type_id" FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE component_type_component_function
	ADD CONSTRAINT "fk_cmptypcf_comp_func" FOREIGN KEY (component_function) REFERENCES val_component_function(component_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE component_type_component_function
	ADD CONSTRAINT "fk_cmptypecf_comp_typ_id" FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE component_type_slot_template
	ALTER COLUMN slot_side
		SET DEFAULT 'FRONT';


ALTER TABLE component_type_slot_template
	ADD CONSTRAINT "fk_comp_typ_slt_tmplt_cmptypid" FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE component_type_slot_template
	ADD CONSTRAINT "fk_comp_typ_slt_tmplt_slttypid" FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE contract
	ADD CONSTRAINT "fk_contract_company_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE contract_type
	ADD CONSTRAINT "fk_contract_contract_id" FOREIGN KEY (contract_id) REFERENCES contract(contract_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE contract_type
	ADD CONSTRAINT "fk_contract_contract_type" FOREIGN KEY (contract_type) REFERENCES val_contract_type(contract_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE department
	ADD CONSTRAINT check_yes_no_dept_isact CHECK  ( is_active IN ('Y', 'N') ) ;

ALTER TABLE department
	ALTER COLUMN is_active
		SET DEFAULT 'Y';


ALTER TABLE department
	ADD CONSTRAINT "fk_dept_usr_col_id" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE department
	ADD CONSTRAINT "fk_dept_mgr_acct_id" FOREIGN KEY (manager_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE department
	ADD CONSTRAINT "fk_dept_badge_type" FOREIGN KEY (default_badge_type_id) REFERENCES badge_type(badge_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE department
	ADD CONSTRAINT "fk_dept_company" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE device
	ADD CONSTRAINT check_yes_no_1955318701 CHECK  ( is_virtual_device IN ('Y', 'N') ) ;

ALTER TABLE device
	ADD CONSTRAINT check_yes_no_1952460860 CHECK  ( is_locally_managed IN ('Y', 'N') ) ;

ALTER TABLE device
	ALTER COLUMN operating_system_id
		SET DEFAULT 0;

ALTER TABLE device
	ALTER COLUMN is_virtual_device
		SET DEFAULT 'N';

ALTER TABLE device
	ALTER COLUMN is_locally_managed
		SET DEFAULT 'Y';


ALTER TABLE device
	ADD CONSTRAINT "fk_chasloc_chass_devid" FOREIGN KEY (chassis_location_id) REFERENCES chassis_location(chassis_location_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE device
	ADD CONSTRAINT "fk_device_comp_id" FOREIGN KEY (component_id) REFERENCES component(component_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_device_dev_val_status" FOREIGN KEY (device_status) REFERENCES val_device_status(device_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_device_dev_v_svcenv" FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_device_id_dnsrecord" FOREIGN KEY (identifying_dns_record_id) REFERENCES dns_record(dns_record_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE device
	ADD CONSTRAINT "fk_device_ref_parent_device" FOREIGN KEY (parent_device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_device_site_code" FOREIGN KEY (site_code) REFERENCES site(site_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_dev_chass_loc_id_mod_enfc" FOREIGN KEY (chassis_location_id,parent_device_id,device_type_id) REFERENCES chassis_location(chassis_location_id,chassis_device_id,module_device_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE device
	ADD CONSTRAINT "fk_dev_devtp_id" FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_dev_os_id" FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device
	ADD CONSTRAINT "fk_dev_rack_location_id" FOREIGN KEY (rack_location_id) REFERENCES rack_location(rack_location_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN device.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE device_collection
	ADD CONSTRAINT "fk_devc_devctyp_id" FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN device_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "fk_devcolascrt_devcolid" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "fk_x509_certificate_file_fmt" FOREIGN KEY (x509_file_format) REFERENCES val_x509_certificate_file_format(x509_certificate_file_format)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "fk_devcol_asscrt_acctcolid" FOREIGN KEY (file_group_account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "fk_x509_key_usg_attrbt_dvc" FOREIGN KEY (x509_signed_certificate_id,x509_key_usage) REFERENCES x509_key_usage_attribute(x509_signed_certificate_id,x509_key_usage)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "fk_key_usg_reason_for_assng_d" FOREIGN KEY (key_usage_reason_for_assignment) REFERENCES val_key_usage_reason_for_assignment(key_usage_reason_for_assignment)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_assigned_certificate
	ADD CONSTRAINT "fk_devcolascrt_flownacctid" FOREIGN KEY (file_owner_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE device_collection_assigned_certificate IS 'Actual  assignment of the usage category APPLICATION Certificates to Device Collections.';

COMMENT ON COLUMN device_collection_assigned_certificate.x509_signed_certificate_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN device_collection_assigned_certificate.x509_key_usage IS 'Name of the Certificate.';

COMMENT ON COLUMN device_collection_assigned_certificate.x509_file_format IS 'Format Name of the file containing Certificate information. Example; keytool, rsa';

COMMENT ON COLUMN device_collection_assigned_certificate.file_location_path IS 'Alphanumeric representation of the path leading to the file.';

COMMENT ON COLUMN device_collection_assigned_certificate.key_tool_label IS 'Alphanumeric representation of the label attached to the certificate by Key Tool';

COMMENT ON COLUMN device_collection_assigned_certificate.file_access_mode IS 'Numeric representation of the File Access Mode.';

COMMENT ON COLUMN device_collection_assigned_certificate.file_owner_account_id IS 'Identifier of the file owner.';

COMMENT ON COLUMN device_collection_assigned_certificate.file_group_account_collection_id IS 'Identifies user collection that corresponds to a unix group for the file to be owned by';

COMMENT ON COLUMN device_collection_assigned_certificate.key_usage_reason_for_assignment IS 'Uniquely identifies and indicates reason for assignment.';


ALTER TABLE device_collection_device
	ADD CONSTRAINT "fk_devcolldev_dev_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_device
	ADD CONSTRAINT "fk_devcolldev_dev_colid" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_collection_hier
	ADD CONSTRAINT "fk_devcollhier_devcol_id" FOREIGN KEY (child_device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_hier
	ADD CONSTRAINT "fk_devcollhier_pdevcol_id" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT "fk_dev_coll_ssh_key_ssh_key" FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT "fk_dev_coll_ssh_key_devcoll" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_collection_ssh_key
	ADD CONSTRAINT "fk_dev_coll_ssh_key_acct_col" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN device_collection_ssh_key.ssh_key_id IS 'SSH Public Key that gets placed in a user''s authorized keys file';

COMMENT ON COLUMN device_collection_ssh_key.device_collection_id IS 'Device collection that gets this key assigned to users';

COMMENT ON COLUMN device_collection_ssh_key.account_collection_id IS 'Destination account(s) that get the ssh keys';


ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT "fk_dev_encap_domain_devid" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT "fk_dev_encap_domain_encaptyp" FOREIGN KEY (encapsulation_type) REFERENCES val_encapsulation_type(encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_encapsulation_domain
	ADD CONSTRAINT "fk_dev_encap_domain_enc_domtyp" FOREIGN KEY (encapsulation_domain,encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain,encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_layer2_network
	ADD CONSTRAINT "fk_device_l2_net_devid" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_layer2_network
	ADD CONSTRAINT "fk_device_l2_net_l2netid" FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_management_controller
	ADD CONSTRAINT "fk_dvc_mgmt_ctrl_mgr_dev_id" FOREIGN KEY (manager_device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_management_controller
	ADD CONSTRAINT "fk_dev_mgmt_ctlr_dev_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_management_controller
	ADD CONSTRAINT "fk_dev_mgmt_cntrl_val_ctrl_typ" FOREIGN KEY (device_management_control_type) REFERENCES val_device_management_controller_type(device_mgmt_control_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_note
	ADD CONSTRAINT ckc_note_user_device_n CHECK  ( note_user= upper(note_user) ) ;


ALTER TABLE device_note
	ADD CONSTRAINT "fk_device_note_device" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_ssh_key
	ADD CONSTRAINT "fk_dev_ssh_key_device_id" FOREIGN KEY (ssh_key_id) REFERENCES ssh_key(ssh_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_ssh_key
	ADD CONSTRAINT "fk_dev_ssh_key_ssh_key_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE device_ticket
	ADD CONSTRAINT "fk_dev_tkt_dev_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_ticket
	ADD CONSTRAINT "fk_dev_tkt_tkt_system" FOREIGN KEY (ticketing_system_id) REFERENCES ticketing_system(ticketing_system_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE device_ticket IS 'associates devices and trouble tickets together (external to jazzhands)';

COMMENT ON COLUMN device_ticket.ticket_number IS 'trouble ticketing system id';

COMMENT ON COLUMN device_ticket.device_ticket_notes IS 'free form notes about the ticket/device association';


ALTER TABLE device_type
	ADD CONSTRAINT check_yes_no_279922778 CHECK  ( has_802_3_interface IN ('Y', 'N') ) ;

ALTER TABLE device_type
	ADD CONSTRAINT check_yes_no_956213646 CHECK  ( has_802_11_interface IN ('Y', 'N') ) ;

ALTER TABLE device_type
	ADD CONSTRAINT check_yes_no_1419559865 CHECK  ( snmp_capable IN ('Y', 'N') ) ;

ALTER TABLE device_type
	ADD CONSTRAINT check_yes_no_1345939137 CHECK  ( is_chassis IN ('Y', 'N') ) ;

ALTER TABLE device_type
	ALTER COLUMN has_802_3_interface
		SET DEFAULT 'N';

ALTER TABLE device_type
	ALTER COLUMN has_802_11_interface
		SET DEFAULT 'N';

ALTER TABLE device_type
	ALTER COLUMN snmp_capable
		SET DEFAULT 'N';

ALTER TABLE device_type
	ALTER COLUMN is_chassis
		SET DEFAULT 'N';


ALTER TABLE device_type
	ADD CONSTRAINT "fk_device_t_fk_device_val_proc" FOREIGN KEY (processor_architecture) REFERENCES val_processor_architecture(processor_architecture)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_type
	ADD CONSTRAINT "fk_devtyp_company" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE device_type
	ADD CONSTRAINT "fk_dev_typ_idealized_dev_id" FOREIGN KEY (idealized_device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_type
	ADD CONSTRAINT "fk_dev_typ_tmplt_dev_typ_id" FOREIGN KEY (template_device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_type
	ADD CONSTRAINT "fk_fevtyp_component_id" FOREIGN KEY (component_type_id) REFERENCES component_type(component_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE device_type IS 'Conceptual device type.  This represents how it is typically referred to rather than a specific model number.  There may be many models (components) that are represented by one device type.';

COMMENT ON COLUMN device_type.component_type_id IS 'reference to the type of hardware that underlies this type';

COMMENT ON COLUMN device_type.template_device_id IS 'Represents a non-real but template device that is used to describe how to setup a device when its inserted into the database with this device type.  Its used to get port names and other information correct when it needs to be inserted before probing.  Probing may deviate from the template.';

COMMENT ON COLUMN device_type.device_type_name IS 'Human readable name of the device type.  The company and a model can be gleaned from component.';

COMMENT ON COLUMN device_type.idealized_device_id IS 'Indicates what a device of this type looks like; primarily used for either reverse engineering a probe to a device type or valdating that a device type has all the pieces it is expcted to.  This device is typically not real.';


ALTER TABLE device_type_module
	ADD CONSTRAINT ckc_dt_mod_dt_side CHECK  ( DEVICE_TYPE_SIDE in ('FRONT','BACK') ) ;

ALTER TABLE device_type_module
	ALTER COLUMN device_type_side
		SET DEFAULT 'FRONT';


ALTER TABLE device_type_module
	ADD CONSTRAINT "fk_devt_mod_dev_type_id" FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN device_type_module.device_type_id IS 'Device Type of the Container Device (Chassis)';

COMMENT ON COLUMN device_type_module.device_type_module_name IS 'Name used to describe the module programatically.';

COMMENT ON COLUMN device_type_module.device_type_x_offset IS 'Horizontal offset from left to right';

COMMENT ON COLUMN device_type_module.device_type_y_offset IS 'Vertical offset from top to bottom';

COMMENT ON COLUMN device_type_module.device_type_z_offset IS 'Offset inside the device (front to back, yes, that is Z).  Only this or device_type_side may be set.';

COMMENT ON COLUMN device_type_module.device_type_side IS 'Only this or z_offset may be set.  Front or back of the chassis/container device_type';


ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT "fk_dt_mod_dev_type_dtmod" FOREIGN KEY (device_type_id,device_type_module_name) REFERENCES device_type_module(device_type_id,device_type_module_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE device_type_module_device_type
	ADD CONSTRAINT "fk_dt_mod_dev_type_mod_dtid" FOREIGN KEY (module_device_type_id) REFERENCES device_type(device_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE device_type_module_device_type IS 'Used to validate that a given module device_type is allowed to be placed inside a specific module in a chassis_device_type';

COMMENT ON COLUMN device_type_module_device_type.module_device_type_id IS 'Id of a module that is permitted to be placed in this slot';

COMMENT ON COLUMN device_type_module_device_type.device_type_id IS 'Device Type of the Container Device (Chassis)';

COMMENT ON COLUMN device_type_module_device_type.device_type_module_name IS 'Name used to describe the module programatically.';


ALTER TABLE dns_change_record
	ADD CONSTRAINT "fk_dns_chg_dns_domain" FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_change_record
	ADD CONSTRAINT "fk_dnschgrec_ip_universe" FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE dns_domain
	ADD CONSTRAINT "fk_dnsdom_dnsdom_id" FOREIGN KEY (parent_dns_domain_id) REFERENCES dns_domain(dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_domain
	ADD CONSTRAINT "fk_dns_dom_dns_dom_typ" FOREIGN KEY (dns_domain_type) REFERENCES val_dns_domain_type(dns_domain_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN dns_domain.soa_name IS 'legacy name for zone.  This is being replaced with dns_domain_name and the other should be set and not this one (which will be syncd by trigger until it goes away).';

COMMENT ON COLUMN dns_domain.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE dns_domain_collection
	ADD CONSTRAINT "fk_dns_dom_coll_typ_val" FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN dns_domain_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE dns_domain_collection_dns_domain
	ADD CONSTRAINT "fk_dns_dom_coll_dns_domid" FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_domain_collection_dns_domain
	ADD CONSTRAINT "fk_dns_dom_coll_dns_dom_dns_dom_id" FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT "fk_dns_domain_coll_id_child" FOREIGN KEY (child_dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_domain_collection_hier
	ADD CONSTRAINT "fk_dns_domain_coll_id" FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT check_yes_no_417925201 CHECK  ( should_generate IN ('Y', 'N') ) ;

ALTER TABLE dns_domain_ip_universe
	ALTER COLUMN soa_serial
		SET DEFAULT 0;


ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT "fk_dnsdom_ipu_dnsdomid" FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_domain_ip_universe
	ADD CONSTRAINT "fk_dnsdom_ipu_ipu" FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE dns_record
	ADD CONSTRAINT ckc_dns_srv_protocol_dns_reco CHECK  ( DNS_SRV_PROTOCOL is null or (DNS_SRV_PROTOCOL in ('tcp','udp') and DNS_SRV_PROTOCOL = lower(DNS_SRV_PROTOCOL)) ) ;

ALTER TABLE dns_record
	ADD CONSTRAINT check_yes_no_689258637 CHECK  ( should_generate_ptr IN ('Y', 'N') ) ;

ALTER TABLE dns_record
	ADD CONSTRAINT check_yes_no_1295081792 CHECK  ( is_enabled IN ('Y', 'N') ) ;

ALTER TABLE dns_record
	ALTER COLUMN dns_class
		SET DEFAULT 'IN';

ALTER TABLE dns_record
	ALTER COLUMN should_generate_ptr
		SET DEFAULT 'Y';

ALTER TABLE dns_record
	ALTER COLUMN is_enabled
		SET DEFAULT 'Y';


ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dns_record_vdnsclass" FOREIGN KEY (dns_class) REFERENCES val_dns_class(dns_class)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dnsrec_vdnssrvsrvc" FOREIGN KEY (dns_srv_service) REFERENCES val_dns_srv_service(dns_srv_service)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dnsid_dnsdom_id" FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dnsid_nblk_id" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dnsrecord_vdnstype" FOREIGN KEY (dns_type) REFERENCES val_dns_type(dns_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dnsvalref_dns_recid" FOREIGN KEY (dns_value_record_id) REFERENCES dns_record(dns_record_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_dns_rec_ip_universe" FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record
	ADD CONSTRAINT "fk_ref_dnsrec_dnserc" FOREIGN KEY (reference_dns_record_id,dns_domain_id) REFERENCES dns_record(dns_record_id,dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE dns_record_relation
	ADD CONSTRAINT "fk_dnsrec_ref_vdnsrecrltntype" FOREIGN KEY (dns_record_relation_type) REFERENCES val_dns_record_relation_type(dns_record_relation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record_relation
	ADD CONSTRAINT "fk_dns_rec_ref_dns_rec_rltn" FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE dns_record_relation
	ADD CONSTRAINT "fk_dnsrec_ref_dnsrecrltn_rl_id" FOREIGN KEY (related_dns_record_id) REFERENCES dns_record(dns_record_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE encapsulation_domain
	ADD CONSTRAINT "fk_encap_domain_encap_typ" FOREIGN KEY (encapsulation_type) REFERENCES val_encapsulation_type(encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE encapsulation_range
	ADD CONSTRAINT "fk_encap_range_parent_encap_id" FOREIGN KEY (parent_encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE encapsulation_range
	ADD CONSTRAINT "fk_encap_range_sitecode" FOREIGN KEY (site_code) REFERENCES site(site_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE encapsulation_range IS 'Captures how tables are assigned administratively.  This is not use for enforcement but primarily for presentation';


ALTER TABLE encryption_key
	ADD CONSTRAINT "fk_enckey_enckeypurpose_val" FOREIGN KEY (encryption_key_purpose,encryption_key_purpose_version) REFERENCES val_encryption_key_purpose(encryption_key_purpose,encryption_key_purpose_version)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE encryption_key
	ADD CONSTRAINT "fk_enckey_encmethod_val" FOREIGN KEY (encryption_method) REFERENCES val_encryption_method(encryption_method)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE encryption_key IS 'Keep information on keys used to encrypt sensitive data in the schema';

COMMENT ON COLUMN encryption_key.encryption_key_db_value IS 'part of 3-tuple that is the key used to encrypt.  The other portions are provided by a user and stored in the key_crypto package';

COMMENT ON COLUMN encryption_key.encryption_key_purpose IS 'indicates the purpose of infrastructure providing the key.  Used externally by applications to manage their portion of the key';

COMMENT ON COLUMN encryption_key.encryption_key_purpose_version IS 'indicates the version of the application portion of the key.  Used externally by applications to manage their portion of the key';

COMMENT ON COLUMN encryption_key.encryption_method IS 'Text representation of the method of encryption.  Format is the same as Kerberos uses such as in rfc3962';


ALTER TABLE inter_component_connection
	ADD CONSTRAINT "fk_intercomp_conn_slot1_id" FOREIGN KEY (slot1_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE inter_component_connection
	ADD CONSTRAINT "fk_intercomp_conn_slot2_id" FOREIGN KEY (slot2_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE inter_component_connection
	ADD CONSTRAINT "fk_intercom_conn_circ_id" FOREIGN KEY (circuit_id) REFERENCES circuit(circuit_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE ip_universe
	ADD CONSTRAINT check_yes_no_739095954 CHECK  ( should_generate_dns IN ('Y', 'N') ) ;


ALTER TABLE ip_universe
	ADD CONSTRAINT "fk_ip_universe_namespace" FOREIGN KEY (ip_namespace) REFERENCES val_ip_namespace(ip_namespace)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN ip_universe.ip_namespace IS 'defeines the namespace for a given ip universe -- all universes in this namespace are considered unique for netblock validations';

COMMENT ON COLUMN ip_universe.should_generate_dns IS 'Indicates if any zones should generated rooted in this universe.   Primarily used to turn off DNS generation for universes that exist as shims between two networks (such as the internet can see, inside can not, for inbound NAT''d addresses).';


ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT check_yes_no_1997260291 CHECK  ( propagate_dns IN ('Y', 'N') ) ;

ALTER TABLE ip_universe_visibility
	ALTER COLUMN propagate_dns
		SET DEFAULT 'Y';


ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT "fk_ip_universe_vis_ip_univ" FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE ip_universe_visibility
	ADD CONSTRAINT "fk_ip_universe_vis_ip_univ_vis" FOREIGN KEY (visible_ip_universe_id) REFERENCES ip_universe(ip_universe_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE klogin
	ADD CONSTRAINT "fk_klgn_acct_id" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE klogin
	ADD CONSTRAINT "fk_klgn_acct_dst_id" FOREIGN KEY (destination_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE klogin
	ADD CONSTRAINT "fk_klogin_realmid" FOREIGN KEY (krb_realm_id) REFERENCES kerberos_realm(krb_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE klogin
	ADD CONSTRAINT "fk_klogin_ref_acct_col_id" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE klogin_mclass
	ADD CONSTRAINT "fk_klgnmcl_klogn_id" FOREIGN KEY (klogin_id) REFERENCES klogin(klogin_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE klogin_mclass
	ADD CONSTRAINT "fk_klgnmcl_devcoll_id" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE layer2_connection
	ADD CONSTRAINT "fk_l2_conn_l1port" FOREIGN KEY (logical_port1_id) REFERENCES logical_port(logical_port_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_connection
	ADD CONSTRAINT "fk_l2_conn_l2port" FOREIGN KEY (logical_port2_id) REFERENCES logical_port(logical_port_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE layer2_connection_layer2_network
	ADD CONSTRAINT "fk_l2cl2n_l2net_id_encap_typ" FOREIGN KEY (layer2_network_id,encapsulation_type) REFERENCES layer2_network(layer2_network_id,encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_connection_layer2_network
	ADD CONSTRAINT "fk_l2c_l2n_encap_mode_type" FOREIGN KEY (encapsulation_mode,encapsulation_type) REFERENCES val_encapsulation_mode(encapsulation_mode,encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_connection_layer2_network
	ADD CONSTRAINT "fk_l2c_l2n_l2connid" FOREIGN KEY (layer2_connection_id) REFERENCES layer2_connection(layer2_connection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_connection_layer2_network
	ADD CONSTRAINT "fk_l2c_l2n_l2netid" FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE layer2_network
	ADD CONSTRAINT "fk_l2_net_encap_domain" FOREIGN KEY (encapsulation_domain,encapsulation_type) REFERENCES encapsulation_domain(encapsulation_domain,encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_network
	ADD CONSTRAINT "fk_l2_net_encap_range_id" FOREIGN KEY (encapsulation_range_id) REFERENCES encapsulation_range(encapsulation_range_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN layer2_network.encapsulation_range_id IS 'Administrative information about which range this is a part of';

COMMENT ON COLUMN layer2_network.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE layer2_network_collection
	ADD CONSTRAINT "fk_l2netcoll_type" FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_collection_type(layer2_network_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN layer2_network_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT "fk_l2net_collhier_chldl2net" FOREIGN KEY (child_layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_network_collection_hier
	ADD CONSTRAINT "fk_l2net_collhier_l2net" FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE layer2_network_collection_layer2_network
	ADD CONSTRAINT "fk_l2netcl2net_collid" FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer2_network_collection_layer2_network
	ADD CONSTRAINT "fk_l2netcl2net_l2netid" FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE layer3_interface
	ADD CONSTRAINT check_yes_no_712537714 CHECK  ( is_interface_up IN ('Y', 'N') ) ;

ALTER TABLE layer3_interface
	ADD CONSTRAINT check_yes_no_472235856 CHECK  ( should_monitor IN ('Y', 'N') ) ;

ALTER TABLE layer3_interface
	ADD CONSTRAINT check_yes_no_403095919 CHECK  ( should_manage IN ('Y', 'N') ) ;

ALTER TABLE layer3_interface
	ADD CONSTRAINT ckc_netint_parent_role_1026598895 CHECK  ( parent_relation_type IN ('NONE', 'SUBINTERFACE', 'SECONDARY') ) ;

ALTER TABLE layer3_interface
	ALTER COLUMN is_interface_up
		SET DEFAULT 'Y';

ALTER TABLE layer3_interface
	ALTER COLUMN should_monitor
		SET DEFAULT 'Y';

ALTER TABLE layer3_interface
	ALTER COLUMN should_manage
		SET DEFAULT 'Y';


ALTER TABLE layer3_interface
	ADD CONSTRAINT "fk_net_int_lgl_port_id" FOREIGN KEY (logical_port_id,device_id) REFERENCES logical_port(logical_port_id,device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_interface
	ADD CONSTRAINT "fk_netint_device_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_interface
	ADD CONSTRAINT "fk_netint_ref_parentnetint" FOREIGN KEY (parent_layer3_interface_id) REFERENCES layer3_interface(layer3_interface_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_interface
	ADD CONSTRAINT "fk_netint_slot_id" FOREIGN KEY (slot_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_interface
	ADD CONSTRAINT "fk_netint_netinttyp_id" FOREIGN KEY (layer3_interface_type) REFERENCES val_network_interface_type(network_interface_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN layer3_interface.slot_id IS 'to be dropped after transition to logical_ports are complete.';

ALTER TABLE layer3_interface_netblock
	ALTER COLUMN network_interface_rank
		SET DEFAULT 0;


ALTER TABLE layer3_interface_netblock
	ADD CONSTRAINT "fk_netint_nb_nblk_id" FOREIGN KEY (layer3_interface_id,device_id) REFERENCES layer3_interface(layer3_interface_id,device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE layer3_interface_netblock
	ADD CONSTRAINT "fk_netint_nb_netint_id" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

COMMENT ON COLUMN layer3_interface_netblock.network_interface_rank IS 'specifies the order of priority for the ip address.  generally only the highest priority matters (or highest priority v4 and v6) and is the "primary" if the underlying device supports it.';


ALTER TABLE layer3_interface_purpose
	ADD CONSTRAINT "fk_netint_purpose_device_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE layer3_interface_purpose
	ADD CONSTRAINT "fk_netint_purpose_val_netint_purp" FOREIGN KEY (network_interface_purpose) REFERENCES val_network_interface_purpose(network_interface_purpose)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_interface_purpose
	ADD CONSTRAINT "fk_netint_purp_dev_ni_id" FOREIGN KEY (layer3_interface_id,device_id) REFERENCES layer3_interface(layer3_interface_id,device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE layer3_network
	ADD CONSTRAINT "fk_l3net_l2net" FOREIGN KEY (layer2_network_id) REFERENCES layer2_network(layer2_network_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_network
	ADD CONSTRAINT "fk_l3net_rndv_pt_nblk_id" FOREIGN KEY (rendezvous_netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_network
	ADD CONSTRAINT "fk_l3_net_def_gate_nbid" FOREIGN KEY (default_gateway_netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_network
	ADD CONSTRAINT "fk_layer3_network_netblock_id" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN layer3_network.rendezvous_netblock_id IS 'Multicast Rendevous Point Address';

COMMENT ON COLUMN layer3_network.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE layer3_network_collection
	ADD CONSTRAINT "fk_l3_netcol_netcol_type" FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_collection_type(layer3_network_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN layer3_network_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT "fk_l3nethierl3netid" FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_network_collection_hier
	ADD CONSTRAINT "fk_l3nethier_chld_l3netid" FOREIGN KEY (child_layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE layer3_network_collection_layer3_network
	ADD CONSTRAINT "fk_l3netcol_l3_net_l3netcolid" FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE layer3_network_collection_layer3_network
	ADD CONSTRAINT "fk_l3netcol_l3_net_l3netid" FOREIGN KEY (layer3_network_id) REFERENCES layer3_network(layer3_network_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE logical_port
	ADD CONSTRAINT "fk_logical_port_device_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_port
	ADD CONSTRAINT "fk_logcal_port_mlag_peering_id" FOREIGN KEY (mlag_peering_id) REFERENCES mlag_peering(mlag_peering_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_port
	ADD CONSTRAINT "fk_logical_port_lg_port_type" FOREIGN KEY (logical_port_type) REFERENCES val_logical_port_type(logical_port_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_port
	ADD CONSTRAINT "fk_logical_port_parent_id" FOREIGN KEY (parent_logical_port_id) REFERENCES logical_port(logical_port_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE logical_port_slot
	ADD CONSTRAINT "fk_lgl_port_slot_lgl_port_id" FOREIGN KEY (logical_port_id) REFERENCES logical_port(logical_port_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_port_slot
	ADD CONSTRAINT "fk_lgl_port_slot_slot_id" FOREIGN KEY (slot_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_volume
	ALTER COLUMN logical_volume_type
		SET DEFAULT 'legacy';


ALTER TABLE logical_volume
	ADD CONSTRAINT "fk_log_volume_log_vol_type" FOREIGN KEY (logical_volume_type) REFERENCES val_logical_volume_type(logical_volume_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_volume
	ADD CONSTRAINT "fk_logvol_device_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE logical_volume
	ADD CONSTRAINT "fk_logvol_fstype" FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE logical_volume
	ADD CONSTRAINT "fk_logvol_vgid" FOREIGN KEY (volume_group_id,device_id) REFERENCES volume_group(volume_group_id,device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE logical_volume_property
	ADD CONSTRAINT "fk_lvol_prop_lvid_fstyp" FOREIGN KEY (logical_volume_id,filesystem_type) REFERENCES logical_volume(logical_volume_id,filesystem_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE logical_volume_property
	ADD CONSTRAINT "fk_lvol_prop_lvpn_fsty" FOREIGN KEY (logical_volume_property_name,filesystem_type) REFERENCES val_logical_volume_property(logical_volume_property_name,filesystem_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE logical_volume_property
	ADD CONSTRAINT "fk_lvprop_purpose" FOREIGN KEY (logical_volume_purpose) REFERENCES val_logical_volume_purpose(logical_volume_purpose)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE logical_volume_property
	ADD CONSTRAINT "fk_lvprop_type" FOREIGN KEY (logical_volume_type) REFERENCES val_logical_volume_type(logical_volume_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN logical_volume_property.filesystem_type IS 'THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';


ALTER TABLE logical_volume_purpose
	ADD CONSTRAINT "fk_lvpurp_lvid" FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE logical_volume_purpose
	ADD CONSTRAINT "fk_lvpurp_val_lgpuprp" FOREIGN KEY (logical_volume_purpose) REFERENCES val_logical_volume_purpose(logical_volume_purpose)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE mlag_peering
	ADD CONSTRAINT "fk_mlag_peering_devid1" FOREIGN KEY (device1_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE mlag_peering
	ADD CONSTRAINT "fk_mlag_peering_devid2" FOREIGN KEY (device2_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE netblock
	ADD CONSTRAINT check_yes_no_896740574 CHECK  ( is_single_address IN ('Y', 'N') ) ;

ALTER TABLE netblock
	ADD CONSTRAINT check_yes_no_356293545 CHECK  ( can_subnet IN ('Y', 'N') ) ;

ALTER TABLE netblock
	ALTER COLUMN netblock_type
		SET DEFAULT 'default';


ALTER TABLE netblock
	ADD CONSTRAINT "fk_nblk_ip_universe_id" FOREIGN KEY (ip_universe_id) REFERENCES ip_universe(ip_universe_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE netblock
	ADD CONSTRAINT "fk_netblock_nblk_typ" FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE netblock
	ADD CONSTRAINT "fk_netblock_v_netblock_stat" FOREIGN KEY (netblock_status) REFERENCES val_netblock_status(netblock_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE netblock
	ADD CONSTRAINT "fk_netblk_netblk_parid" FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  
	INITIALLY DEFERRED  ;

COMMENT ON COLUMN netblock.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE netblock_collection
	ADD CONSTRAINT "fk_nblk_coll_v_nblk_c_typ" FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN netblock_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT "fk_nblk_c_hier_chld_nc" FOREIGN KEY (child_netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE netblock_collection_hier
	ADD CONSTRAINT "fk_nblk_c_hier_prnt_nc" FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT "fk_nblk_col_nblk_nblkid" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE netblock_collection_netblock
	ADD CONSTRAINT "fk_nblk_col_nblk_nbcolid" FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE network_range
	ADD CONSTRAINT "fk_net_range_dns_domain_id" FOREIGN KEY (dns_domain_id) REFERENCES dns_domain(dns_domain_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_range
	ADD CONSTRAINT "fk_netrng_netrng_typ" FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_range
	ADD CONSTRAINT "fk_netrng_prngnblkid" FOREIGN KEY (parent_netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_range
	ADD CONSTRAINT "fk_net_range_start_netblock" FOREIGN KEY (start_netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_range
	ADD CONSTRAINT "fk_net_range_stop_netblock" FOREIGN KEY (stop_netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN network_range.parent_netblock_id IS 'The netblock where the range appears.  This can be of a different type than start/stop netblocks, but start/stop need to be within the parent.';


ALTER TABLE network_service
	ADD CONSTRAINT check_yes_no_667542475 CHECK  ( is_monitored IN ('Y', 'N') ) ;


ALTER TABLE network_service
	ADD CONSTRAINT "fk_netsvc_netsvctyp_id" FOREIGN KEY (network_service_type) REFERENCES val_network_service_type(network_service_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_service
	ADD CONSTRAINT "fk_netsvc_csvcenv" FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_service
	ADD CONSTRAINT "fk_netsvc_dnsid_id" FOREIGN KEY (dns_record_id) REFERENCES dns_record(dns_record_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_service
	ADD CONSTRAINT "fk_netsvc_device_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE network_service
	ADD CONSTRAINT "fk_netsvc_netint_id" FOREIGN KEY (network_interface_id) REFERENCES layer3_interface(layer3_interface_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE operating_system
	ADD CONSTRAINT "fk_os_company" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE operating_system
	ADD CONSTRAINT "fk_os_os_family" FOREIGN KEY (operating_system_family) REFERENCES val_operating_system_family(operating_system_family)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT "fk_os_snap_osid" FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE operating_system_snapshot
	ADD CONSTRAINT "fk_os_snap_snap_type" FOREIGN KEY (operating_system_snapshot_type) REFERENCES val_operating_system_snapshot_type(operating_system_snapshot_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person
	ADD CONSTRAINT ckc_gender_legacy_489562276 CHECK  ( GENDER is null or (GENDER in ('M','F','U') and GENDER = upper(GENDER)) ) ;

ALTER TABLE person
	ADD CONSTRAINT ckc_shirt_size_349995592 CHECK  ( SHIRT_SIZE is null or (SHIRT_SIZE in ('XS','S','M','L','XL','XXL','XXXL') and SHIRT_SIZE = upper(SHIRT_SIZE)) ) ;

ALTER TABLE person
	ADD CONSTRAINT ckc_pant_size_134351392 CHECK  ( PANT_SIZE is null or (PANT_SIZE in ('XS','S','M','L','XL','XXL','XXXL') and PANT_SIZE = upper(PANT_SIZE)) ) ;


ALTER TABLE person
	ADD CONSTRAINT "fk_diet_val_diet" FOREIGN KEY (diet) REFERENCES val_diet(diet)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN person.first_name IS 'Legal First Name';

COMMENT ON COLUMN person.middle_name IS 'Legal Middle name or name(s)';

COMMENT ON COLUMN person.last_name IS 'Legal Last Name';

COMMENT ON COLUMN person.preferred_first_name IS 'What the person''s preferred name is called, suitable for official commications.';

COMMENT ON COLUMN person.preferred_last_name IS 'A known last name, typically used if someone has a different married name but professionally is known by something different.';

COMMENT ON COLUMN person.description IS 'free form description, generally unused';

COMMENT ON COLUMN person.nickname IS 'Common nickname for the person, differs from the preferred name in that its more casual.';


ALTER TABLE person_account_realm_company
	ADD CONSTRAINT "fk_ac_ac_rlm_cpy_act_rlm_cpy" FOREIGN KEY (account_realm_id,company_id) REFERENCES account_realm_company(account_realm_id,company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE person_account_realm_company
	ADD CONSTRAINT "fk_person_acct_rlm_cmpy_persnid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person_auth_question
	ADD CONSTRAINT check_yes_no_1358904229 CHECK  ( is_active IN ('Y', 'N') ) ;


ALTER TABLE person_auth_question
	ADD CONSTRAINT "fk_person_auth_question_prsnid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_auth_question
	ADD CONSTRAINT "fk_person_aq_val_auth_ques" FOREIGN KEY (auth_question_id) REFERENCES val_auth_question(auth_question_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE person_auth_question IS 'Captures system user chosen answers to the set of predetermined questions for user authentication purposes.';

COMMENT ON COLUMN person_auth_question.auth_question_id IS 'Uniquely identifies authentication question.';

COMMENT ON COLUMN person_auth_question.user_answer IS 'Records system user answer to the authentication question.';


ALTER TABLE person_company
	ADD CONSTRAINT check_yes_no_1404165584 CHECK  ( is_exempt IN ('Y', 'N') ) ;

ALTER TABLE person_company
	ADD CONSTRAINT check_yes_no_prsncmpy_mgmt CHECK  ( is_management IN ('Y', 'N') ) ;

ALTER TABLE person_company
	ADD CONSTRAINT check_yes_no_676772835 CHECK  ( is_full_time IN ('Y', 'N') ) ;

ALTER TABLE person_company
	ALTER COLUMN is_exempt
		SET DEFAULT 'Y';

ALTER TABLE person_company
	ALTER COLUMN is_management
		SET DEFAULT 'N';

ALTER TABLE person_company
	ALTER COLUMN is_full_time
		SET DEFAULT 'Y';


ALTER TABLE person_company
	ADD CONSTRAINT "fk_person_company_mgrprsn_id" FOREIGN KEY (manager_person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_company
	ADD CONSTRAINT "fk_person_company_prsncmpy_status" FOREIGN KEY (person_company_status) REFERENCES val_person_status(person_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_company
	ADD CONSTRAINT "fk_person_company_prsncmpyrelt" FOREIGN KEY (person_company_relation) REFERENCES val_person_company_relation(person_company_relation)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_company
	ADD CONSTRAINT "fk_person_company_company_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE person_company
	ADD CONSTRAINT "fk_person_company_prsnid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN person_company.nickname IS 'Nickname in the context of a given company.  This is less likely to be used, the value in person is preferrred.';


ALTER TABLE person_company_attribute
	ADD CONSTRAINT "fk_pers_comp_attr_person_comp_id" FOREIGN KEY (company_id,person_id) REFERENCES person_company(company_id,person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE person_company_attribute
	ADD CONSTRAINT "fk_person_comp_att_pers_personid" FOREIGN KEY (attribute_value_person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_company_attribute
	ADD CONSTRAINT "fk_person_comp_attr_val_name" FOREIGN KEY (person_company_attribute_name) REFERENCES val_person_company_attribute_name(person_company_attribute_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN person_company_attribute.attribute_value_person_id IS 'person_id value of the attribute.';

COMMENT ON COLUMN person_company_attribute.attribute_value IS 'string value of the attribute.';


ALTER TABLE person_company_badge
	ADD CONSTRAINT "fk_person_company_badge_pc" FOREIGN KEY (company_id,person_id) REFERENCES person_company(company_id,person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE person_company_badge IS 'badges associated with a person''s relationship to a company';

COMMENT ON COLUMN person_company_badge.badge_id IS 'Identification usually defined externally in a badge system.';


ALTER TABLE person_contact
	ADD CONSTRAINT ckc_contact_privacy_2076759287 CHECK  ( person_contact_privacy IN ('PRIVATE', 'PUBLIC', 'HIDDEN') ) ;


ALTER TABLE person_contact
	ADD CONSTRAINT "fk_prsn_cntct_prscn_loc" FOREIGN KEY (person_contact_location_type) REFERENCES val_person_contact_location_type(person_contact_location_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_contact
	ADD CONSTRAINT "fk_prsn_contect_cr_cmpyid" FOREIGN KEY (person_contact_carrier_company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE person_contact
	ADD CONSTRAINT "fk_person_contact_typ_tec" FOREIGN KEY (person_contact_technology,person_contact_type) REFERENCES val_person_contact_technology(person_contact_technology,person_contact_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_contact
	ADD CONSTRAINT "fk_person_contact_person_id" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_contact
	ADD CONSTRAINT "fk_person_type_iso_code" FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN person_contact.person_contact_carrier_company_id IS 'The Contact''s Carrier Company Id';

COMMENT ON COLUMN person_contact.person_contact_technology IS 'technology sub-type or protocol(phone,mobile,fax,voicemail,conference)';


ALTER TABLE person_image
	ADD CONSTRAINT "fk_person_image_personid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_image
	ADD CONSTRAINT "fk_person_fk_person_val_imag" FOREIGN KEY (image_type) REFERENCES val_image_type(image_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person_image_usage
	ADD CONSTRAINT "fk_person_img_usg_person_img_id" FOREIGN KEY (person_image_id) REFERENCES person_image(person_image_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_image_usage
	ADD CONSTRAINT "fk_person_img_usg_val_prsn_img_usg" FOREIGN KEY (person_image_usage) REFERENCES val_person_image_usage(person_image_usage)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person_location
	ADD CONSTRAINT "fk_persloc_persid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_location
	ADD CONSTRAINT "fk_persloc_persloctyp" FOREIGN KEY (person_location_type) REFERENCES val_person_location_type(person_location_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_location
	ADD CONSTRAINT "fk_persloc_physaddrid" FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE person_location
	ADD CONSTRAINT "fk_persloc_site_code" FOREIGN KEY (site_code) REFERENCES site(site_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person_note
	ADD CONSTRAINT ckc_note_user_system_u CHECK  ( note_user= upper(note_user) ) ;


ALTER TABLE person_note
	ADD CONSTRAINT "fk_person_note_person_id" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person_parking_pass
	ADD CONSTRAINT "fk_person_parking_pass_personid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE person_vehicle
	ADD CONSTRAINT "fk_person_vehicle_prsnid" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE physical_address
	ALTER COLUMN physical_address_type
		SET DEFAULT 'location';


ALTER TABLE physical_address
	ADD CONSTRAINT "fk_physaddr_company_id" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE physical_address
	ADD CONSTRAINT "fk_physaddr_iso_cc" FOREIGN KEY (iso_country_code) REFERENCES val_country_code(iso_country_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE physical_address
	ADD CONSTRAINT "fk_physaddr_type_val" FOREIGN KEY (physical_address_type) REFERENCES val_physical_address_type(physical_address_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE physical_connection
	ADD CONSTRAINT "fk_physconn_slot1_id" FOREIGN KEY (slot1_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE physical_connection
	ADD CONSTRAINT "fk_physconn_slot2_id" FOREIGN KEY (slot2_id) REFERENCES slot(slot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE physical_connection
	ADD CONSTRAINT "fk_physical_conn_v_cable_type" FOREIGN KEY (cable_type) REFERENCES val_cable_type(cable_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE physicalish_volume
	ADD CONSTRAINT "fk_physicalish_vol_pvtype" FOREIGN KEY (physicalish_volume_type) REFERENCES val_physicalish_volume_type(physicalish_volume_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE physicalish_volume
	ADD CONSTRAINT "fk_physvol_compid" FOREIGN KEY (component_id) REFERENCES component(component_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE physicalish_volume
	ADD CONSTRAINT "fk_physvol_device_id" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE physicalish_volume
	ADD CONSTRAINT "fk_physvol_lvid" FOREIGN KEY (logical_volume_id) REFERENCES logical_volume(logical_volume_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE private_key
	ADD CONSTRAINT check_yes_no_1732013376 CHECK  ( is_active IN ('Y', 'N') ) ;

ALTER TABLE private_key
	ALTER COLUMN is_active
		SET DEFAULT 'Y';


ALTER TABLE private_key
	ADD CONSTRAINT "fk_pvtkey_enckey_id" FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE private_key
	ADD CONSTRAINT "fk_pctkey_enctype" FOREIGN KEY (private_key_encryption_type) REFERENCES val_private_key_encryption_type(private_key_encryption_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE private_key IS 'Signed X509 Certificate';

COMMENT ON COLUMN private_key.private_key_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN private_key.private_key IS 'Textual representation of Certificate Private Key. Private Key is a component of X509 standard and is used for encryption.';

COMMENT ON COLUMN private_key.passphrase IS 'passphrase to decrypt key.  If encrypted, encryption_key_id indicates how to decrypt.';

COMMENT ON COLUMN private_key.encryption_key_id IS 'if set, encryption key information for decrypting passphrase.';

COMMENT ON COLUMN private_key.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';

COMMENT ON COLUMN private_key.subject_key_identifier IS 'colon seperate byte hex string with X509v3 SKI hash of the key in the same form as the x509 extension.  This should be NOT NULL but its hard to extract sometimes';

COMMENT ON COLUMN private_key.private_key_encryption_type IS 'encryption tyof private key (rsa, dsa, ec, etc).  
';


ALTER TABLE property
	ADD CONSTRAINT ckc_prop_isenbld CHECK  ( is_enabled IN ('Y', 'N') ) ;

ALTER TABLE property
	ALTER COLUMN is_enabled
		SET DEFAULT 'Y';


ALTER TABLE property
	ADD CONSTRAINT "fk_prop_l2_netcollid" FOREIGN KEY (layer2_network_collection_id) REFERENCES layer2_network_collection(layer2_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_l3_netcoll_id" FOREIGN KEY (layer3_network_collection_id) REFERENCES layer3_network_collection(layer3_network_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_net_range_id" FOREIGN KEY (network_range_id) REFERENCES network_range(network_range_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_x509_crt_id" FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_svc_env_coll_id" FOREIGN KEY (service_environment_collection_id) REFERENCES service_environment_collection(service_environment_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_acctid" FOREIGN KEY (account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_acct_col" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_compid" FOREIGN KEY (company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_devcolid" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_nmtyp" FOREIGN KEY (property_name,property_type) REFERENCES val_property(property_name,property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_osid" FOREIGN KEY (operating_system_id) REFERENCES operating_system(operating_system_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_pval_acct_colid" FOREIGN KEY (property_value_account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_pval_pwdtyp" FOREIGN KEY (property_value_password_type) REFERENCES val_password_type(password_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_pval_swpkgid" FOREIGN KEY (property_value_sw_package_id) REFERENCES sw_package(sw_package_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_pval_tokcolid" FOREIGN KEY (property_value_token_collection_id) REFERENCES token_collection(token_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_site_code" FOREIGN KEY (site_code) REFERENCES site(site_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_acctrealmid" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_dns_dom_collect" FOREIGN KEY (dns_domain_collection_id) REFERENCES dns_domain_collection(dns_domain_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_nblk_coll_id" FOREIGN KEY (netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_person_id" FOREIGN KEY (person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_prop_coll_id" FOREIGN KEY (property_name_collection_id) REFERENCES property_name_collection(property_name_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_pv_nblkcol_id" FOREIGN KEY (property_value_netblock_collection_id) REFERENCES netblock_collection(netblock_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_property_val_prsnid" FOREIGN KEY (property_value_person_id) REFERENCES person(person_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_compcoll_id" FOREIGN KEY (company_collection_id) REFERENCES company_collection(company_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_os_snapshot" FOREIGN KEY (operating_system_snapshot_id) REFERENCES operating_system_snapshot(operating_system_snapshot_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property
	ADD CONSTRAINT "fk_prop_pv_devcolid" FOREIGN KEY (property_value_device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE property IS 'generic mechanism to create arbitrary associations between lhs database objects and assign them to zero or one other database objects/strings/lists/etc.  They are trigger enforced based on characteristics in val_property and val_property_value where foreign key enforcement does not work.';

COMMENT ON COLUMN property.property_id IS 'primary key for table to uniquely identify rows.';

COMMENT ON COLUMN property.company_id IS 'LHS settable based on val_property.  THIS COLUMN IS DEPRECATED AND WILL BE REMOVED >= 0.66';

COMMENT ON COLUMN property.device_collection_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.account_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.account_collection_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_value_account_collection_id IS 'RHS, fk to account_collection,    permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.site_code IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_name IS 'textual name of a property';

COMMENT ON COLUMN property.property_type IS 'textual type of a department';

COMMENT ON COLUMN property.property_value IS 'RHS - general purpose column for value of property not defined by other types.  This may be enforced by fk (trigger) if val_property.property_data_type is list (fk is to val_property_value).   permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.property_value_timestamp IS 'RHS - value is a timestamp , permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.start_date IS 'date/time that the assignment takes effect or NULL.  .  The view v_property filters this out.';

COMMENT ON COLUMN property.finish_date IS 'date/time that the assignment ceases taking effect or NULL.  .  The view v_property filters this out.';

COMMENT ON COLUMN property.property_value_password_type IS 'RHS - fk to val_password_type.     permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.property_value_token_collection_id IS 'RHS - fk to token_collection_id.     permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.is_enabled IS 'indiciates if the property is temporarily disabled or not.  The view v_property filters this out.';

COMMENT ON COLUMN property.property_value_sw_package_id IS 'RHS - fk to sw_package.  possibly will be deprecated.     permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.operating_system_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_value_person_id IS 'RHS - fk to person.     permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.person_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_value_netblock_collection_id IS 'RHS - fk to network_collection.    permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.netblock_collection_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_rank IS 'for multivalues, specifies the order.  If set, this basically becomes part of the "ak" for the lhs.';

COMMENT ON COLUMN property.account_realm_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_name_collection_id IS 'LHS settable based on val_property.  NOTE, this is actually collections of property_name,property_type';

COMMENT ON COLUMN property.operating_system_snapshot_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.property_value_device_collection_id IS 'RHS - fk to device_collection.    permitted based on val_property.property_data_type.';

COMMENT ON COLUMN property.dns_domain_collection_id IS 'LHS settable based on val_property';

COMMENT ON COLUMN property.x509_signed_certificate_id IS 'Uniquely identifies Certificate';


ALTER TABLE property_name_collection
	ADD CONSTRAINT "fk_propcol_propcoltype" FOREIGN KEY (property_name_collection_type) REFERENCES val_property_name_collection_type(property_name_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE property_name_collection IS 'Collections of Property Name/Types.  Used for grouping properties for different purposes';


ALTER TABLE property_name_collection_hier
	ADD CONSTRAINT "fk_propcollhier_propcolid" FOREIGN KEY (property_name_collection_id) REFERENCES property_name_collection(property_name_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property_name_collection_hier
	ADD CONSTRAINT "fk_propcollhier_chldpropcoll_id" FOREIGN KEY (child_property_name_collection_id) REFERENCES property_name_collection(property_name_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE property_name_collection_property_name
	ADD CONSTRAINT "fk_prop_col_propnamtyp" FOREIGN KEY (property_name,property_type) REFERENCES val_property(property_name,property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE property_name_collection_property_name
	ADD CONSTRAINT "fk_prop_coll_prop_prop_coll_id" FOREIGN KEY (property_name_collection_id) REFERENCES property_name_collection(property_name_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE property_name_collection_property_name IS 'name,type members of a property collection';

COMMENT ON COLUMN property_name_collection_property_name.property_name IS 'property name for validation purposes';

COMMENT ON COLUMN property_name_collection_property_name.property_type IS 'property type for validation purposes';


ALTER TABLE pseudo_klogin
	ADD CONSTRAINT "fk_pklgn_acct_dstid" FOREIGN KEY (dest_account_id) REFERENCES account(account_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE rack
	ADD CONSTRAINT ckc_rack_style_rack CHECK  ( RACK_STYLE in ('RELAY','CABINET') and RACK_STYLE = upper(RACK_STYLE) ) ;

ALTER TABLE rack
	ADD CONSTRAINT check_yes_no_1604632020 CHECK  ( display_from_bottom IN ('Y', 'N') ) ;


ALTER TABLE rack
	ADD CONSTRAINT "fk_site_rack" FOREIGN KEY (site_code) REFERENCES site(site_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE rack
	ADD CONSTRAINT "fk_rack_v_rack_type" FOREIGN KEY (rack_type) REFERENCES val_rack_type(rack_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE rack_location
	ADD CONSTRAINT ckc_rack_side_location CHECK  ( rack_side in ('FRONT','BACK') ) ;

ALTER TABLE rack_location
	ALTER COLUMN rack_side
		SET DEFAULT 'FRONT';


ALTER TABLE rack_location
	ADD CONSTRAINT "fk_rk_location__rack_id" FOREIGN KEY (rack_id) REFERENCES rack(rack_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE service_environment
	ADD CONSTRAINT "fk_val_svcenv_prodstate" FOREIGN KEY (production_state) REFERENCES val_production_state(production_state)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN service_environment.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE service_environment_collection
	ADD CONSTRAINT "fk_svc_env_col_v_svc_env_type" FOREIGN KEY (service_environment_collection_type) REFERENCES val_service_environment_collection_type(service_env_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN service_environment_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE service_environment_collection_hier
	ADD CONSTRAINT "fk_svcenv_coll_child_svccollid" FOREIGN KEY (child_service_environment_collection_id) REFERENCES service_environment_collection(service_environment_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE service_environment_collection_hier
	ADD CONSTRAINT "fk_svc_env_hier_svc_env_coll_id" FOREIGN KEY (service_environment_collection_id) REFERENCES service_environment_collection(service_environment_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE service_environment_collection_service_environment
	ADD CONSTRAINT "fk_svc_env_col_svc_env" FOREIGN KEY (service_environment_id) REFERENCES service_environment(service_environment_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE service_environment_collection_service_environment
	ADD CONSTRAINT "fk_svc_env_coll_svc_coll_id" FOREIGN KEY (service_environment_collection_id) REFERENCES service_environment_collection(service_environment_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE shared_netblock
	ADD CONSTRAINT "fk_shrdnet_shrdnet_proto" FOREIGN KEY (shared_netblock_protocol) REFERENCES val_shared_netblock_protocol(shared_netblock_protocol)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE shared_netblock
	ADD CONSTRAINT "fk_shared_net_netblock_id" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE shared_netblock_layer3_interface
	ADD CONSTRAINT "fk_shrdnet_netint_shrdnet_id" FOREIGN KEY (shared_netblock_id) REFERENCES shared_netblock(shared_netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE shared_netblock_layer3_interface
	ADD CONSTRAINT "fk_shrdnet_netint_netint_id" FOREIGN KEY (layer3_interface_id) REFERENCES layer3_interface(layer3_interface_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE site
	ADD CONSTRAINT ckc_site_status_site CHECK  ( SITE_STATUS in ('ACTIVE','INACTIVE','OBSOLETE','PLANNED') and SITE_STATUS = upper(SITE_STATUS) ) ;


ALTER TABLE site
	ADD CONSTRAINT "fk_site_colo_company_id" FOREIGN KEY (colo_company_id) REFERENCES company(company_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE site
	ADD CONSTRAINT "fk_site_physaddr_id" FOREIGN KEY (physical_address_id) REFERENCES physical_address(physical_address_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE slot
	ADD CONSTRAINT checkslot_enbled__yes_no CHECK  ( is_enabled IN ('Y', 'N') ) ;

ALTER TABLE slot
	ADD CONSTRAINT ckc_slot_slot_side CHECK  ( slot_side in ('FRONT','BACK') ) ;

ALTER TABLE slot
	ALTER COLUMN is_enabled
		SET DEFAULT 'Y';


ALTER TABLE slot
	ADD CONSTRAINT "fk_slot_cmp_typ_tmp_id" FOREIGN KEY (component_type_slot_template_id) REFERENCES component_type_slot_template(component_type_slot_tmplt_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE slot
	ADD CONSTRAINT "fk_slot_component_id" FOREIGN KEY (component_id) REFERENCES component(component_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE slot
	ADD CONSTRAINT "fk_slot_slot_type_id" FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE slot_type
	ADD CONSTRAINT check_yes_no_1060412074 CHECK  ( remote_slot_permitted IN ('Y', 'N') ) ;

ALTER TABLE slot_type
	ALTER COLUMN remote_slot_permitted
		SET DEFAULT 'N';


ALTER TABLE slot_type
	ADD CONSTRAINT "fk_slot_type_physint_func" FOREIGN KEY (slot_physical_interface_type,slot_function) REFERENCES val_slot_physical_interface(slot_physical_interface_type,slot_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE slot_type
	ADD CONSTRAINT "fk_slot_type_slt_func" FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE slot_type_permitted_component_slot_type
	ADD CONSTRAINT "fk_stpcst_cmp_slt_typ_id" FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE slot_type_permitted_component_slot_type
	ADD CONSTRAINT "fk_stpcst_slot_type_id" FOREIGN KEY (component_slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE slot_type_permitted_remote_slot_type
	ADD CONSTRAINT "fk_stprst_remote_slot_type_id" FOREIGN KEY (remote_slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE slot_type_permitted_remote_slot_type
	ADD CONSTRAINT "fk_stprst_slot_type_id" FOREIGN KEY (slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE ssh_key
	ADD CONSTRAINT "fk_ssh_key_enc_key_id" FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE ssh_key
	ADD CONSTRAINT "fk_ssh_key_ssh_key_type" FOREIGN KEY (ssh_key_type) REFERENCES val_ssh_key_type(ssh_key_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE static_route
	ADD CONSTRAINT "fk_statrt_devsrc_id" FOREIGN KEY (device_source_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE static_route
	ADD CONSTRAINT "fk_statrt_nblk_id" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE static_route
	ADD CONSTRAINT "fk_statrt_netintdst_id" FOREIGN KEY (network_interface_destination_id) REFERENCES layer3_interface(layer3_interface_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE static_route_template
	ADD CONSTRAINT "fk_netblock_st_rt_src_net" FOREIGN KEY (netblock_source_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE static_route_template
	ADD CONSTRAINT "fk_static_rt_net_interface" FOREIGN KEY (network_interface_destination_id) REFERENCES layer3_interface(layer3_interface_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE static_route_template
	ADD CONSTRAINT "fk_netblock_st_rt_dst_net" FOREIGN KEY (netblock_id) REFERENCES netblock(netblock_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT ckc_sudo_alias_name_sudo_ucl CHECK  ( sudo_alias_name ~ '^[A-Z][A-Z0-9_]*$'::text ) ;

ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT check_yes_no_620272763 CHECK  ( requires_password IN ('Y', 'N') ) ;

ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT check_yes_no_1479273988 CHECK  ( can_exec_child IN ('Y', 'N') ) ;


ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT "fk_sudoaccoll_fk_sudo_u_actcl" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT "fk_acctcol_ref_sudoaccldcl_ra" FOREIGN KEY (run_as_account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT "fk_sudo_ucl_fk_dev_co_device_c" FOREIGN KEY (device_collection_id) REFERENCES device_collection(device_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE sudo_account_collection_device_collection
	ADD CONSTRAINT "fk_sudo_acl_fk_sudo_u_sudo_ali" FOREIGN KEY (sudo_alias_name) REFERENCES sudo_alias(sudo_alias_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE sudo_alias
	ADD CONSTRAINT ckc_sudo_alias_name_sudo_ali CHECK  ( sudo_alias_name ~ '^[A-Z][A-Z0-9_]*$'::text ) ;


ALTER TABLE sw_package
	ADD CONSTRAINT "fk_swpkg_ref_vswpkgtype" FOREIGN KEY (sw_package_type) REFERENCES val_sw_package_type(sw_package_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE token
	ADD CONSTRAINT check_yes_no_tkn_islckd CHECK  ( is_token_locked IN ('Y', 'N') ) ;

ALTER TABLE token
	ALTER COLUMN is_token_locked
		SET DEFAULT 'N';


ALTER TABLE token
	ADD CONSTRAINT "fk_token_enc_id_id" FOREIGN KEY (encryption_key_id) REFERENCES encryption_key(encryption_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE token
	ADD CONSTRAINT "fk_token_ref_v_token_status" FOREIGN KEY (token_status) REFERENCES val_token_status(token_status)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE token
	ADD CONSTRAINT "fk_token_ref_v_token_type" FOREIGN KEY (token_type) REFERENCES val_token_type(token_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN token.encryption_key_id IS 'encryption information for token_key, if used';

COMMENT ON COLUMN token.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE token_collection
	ADD CONSTRAINT "fk_tok_col_mem_token_col_type" FOREIGN KEY (token_collection_type) REFERENCES val_token_collection_type(token_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE token_collection IS 'Group tokens together in arbitrary ways.';

COMMENT ON COLUMN token_collection.external_id IS 'opaque id used in remote system to identifty this object.  Used for syncing an authoritative copy.';


ALTER TABLE token_collection_hier
	ADD CONSTRAINT "fk_tok_col_hier_ch_tok_colid" FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE token_collection_hier
	ADD CONSTRAINT "fk_tok_col_hier_tok_colid" FOREIGN KEY (child_token_collection_id) REFERENCES token_collection(token_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE token_collection_hier IS 'Assign individual tokens to groups.';


ALTER TABLE token_collection_token
	ADD CONSTRAINT "fk_tok_col_tok_token_col_id" FOREIGN KEY (token_collection_id) REFERENCES token_collection(token_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE token_collection_token
	ADD CONSTRAINT "fk_tok_col_tok_token_id" FOREIGN KEY (token_id) REFERENCES token(token_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE token_collection_token IS 'Assign individual tokens to groups.';


ALTER TABLE token_sequence
	ADD CONSTRAINT "fk_token_seq_ref_token" FOREIGN KEY (token_id) REFERENCES token(token_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE unix_group
	ADD CONSTRAINT "fk_unxgrp_uclsid" FOREIGN KEY (account_collection_id) REFERENCES account_collection(account_collection_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


COMMENT ON TABLE val_account_collection_relation IS 'Defines type of relationship';


ALTER TABLE val_account_collection_type
	ADD CONSTRAINT check_yes_no_1430080190 CHECK  ( is_infrastructure_type IN ('Y', 'N') ) ;

ALTER TABLE val_account_collection_type
	ADD CONSTRAINT check_yes_no_act_chh CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_account_collection_type
	ALTER COLUMN is_infrastructure_type
		SET DEFAULT 'N';

ALTER TABLE val_account_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


ALTER TABLE val_account_collection_type
	ADD CONSTRAINT "fk_account_realm_ac_type" FOREIGN KEY (account_realm_id) REFERENCES account_realm(account_realm_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN val_account_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_account_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_account_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';

COMMENT ON COLUMN val_account_collection_type.account_realm_id IS 'If set, all accounts in this collection must be of this realm, and all child account collections of this one must have the realm set to be the same.';


ALTER TABLE val_account_role
	ADD CONSTRAINT check_yes_no_769504641 CHECK  ( uid_gid_forced IN ('Y', 'N') ) ;


COMMENT ON TABLE val_account_role IS 'Defines the role for the account, such as primary, administrator, privileged/superuser, test, etc';


ALTER TABLE val_account_type
	ADD CONSTRAINT check_yes_no_726744778 CHECK  ( is_person IN ('Y', 'N') ) ;

ALTER TABLE val_account_type
	ADD CONSTRAINT check_yes_no_836614027 CHECK  ( uid_gid_forced IN ('Y', 'N') ) ;


COMMENT ON TABLE val_account_type IS 'Defines the type of the account (pseudouser or person).  is_person is probably unnecessary and will be dropped in the future.';


ALTER TABLE val_app_key
	ADD CONSTRAINT "fk_val_app_key_group_name" FOREIGN KEY (appaal_group_name) REFERENCES val_appaal_group_name(appaal_group_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_app_key_values
	ADD CONSTRAINT "fk_vappkeyval_ref_vappkey" FOREIGN KEY (appaal_group_name,app_key) REFERENCES val_app_key(appaal_group_name,app_key)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_company_collection_type
	ADD CONSTRAINT check_yes_no_1632390060 CHECK  ( is_infrastructure_type IN ('Y', 'N') ) ;

ALTER TABLE val_company_collection_type
	ADD CONSTRAINT check_yes_no_206713558 CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_company_collection_type
	ALTER COLUMN is_infrastructure_type
		SET DEFAULT 'N';

ALTER TABLE val_company_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON COLUMN val_company_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_company_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_company_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';

ALTER TABLE val_company_type
	ALTER COLUMN company_type_purpose
		SET DEFAULT 'default';


ALTER TABLE val_company_type
	ADD CONSTRAINT "fk_v_comptyp_comptyppurp" FOREIGN KEY (company_type_purpose) REFERENCES val_company_type_purpose(company_type_purpose)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


COMMENT ON TABLE val_company_type_purpose IS 'Mechanism to group company types together, mostly for display or more complicated rules';


ALTER TABLE val_component_property
	ADD CONSTRAINT check_yes_no_1492573689 CHECK  ( is_multivalue IN ('Y', 'N') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_2069511743 CHECK  ( permit_component_type_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_1631999948 CHECK  ( permit_component_function IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_2147412423 CHECK  ( permit_component_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_1778066742 CHECK  ( permit_slot_type_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_199418599 CHECK  ( permit_slot_function IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_186225764 CHECK  ( permit_slot_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ADD CONSTRAINT check_prp_prmt_1651930730 CHECK  ( permit_inter_component_connection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_component_property
	ALTER COLUMN permit_component_type_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_component_property
	ALTER COLUMN permit_component_function
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_component_property
	ALTER COLUMN permit_component_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_component_property
	ALTER COLUMN permit_slot_type_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_component_property
	ALTER COLUMN permit_slot_function
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_component_property
	ALTER COLUMN permit_slot_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_component_property
	ALTER COLUMN permit_inter_component_connection_id
		SET DEFAULT 'PROHIBITED';


ALTER TABLE val_component_property
	ADD CONSTRAINT "fk_vcomp_prop_rqd_slt_func" FOREIGN KEY (required_slot_function) REFERENCES val_slot_function(slot_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_component_property
	ADD CONSTRAINT "fk_comp_prop_comp_prop_type" FOREIGN KEY (component_property_type) REFERENCES val_component_property_type(component_property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_component_property
	ADD CONSTRAINT "fk_cmop_prop_rqd_cmpfunc" FOREIGN KEY (required_component_function) REFERENCES val_component_function(component_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_component_property
	ADD CONSTRAINT "fk_comp_prop_rqd_cmptypid" FOREIGN KEY (required_component_type_id) REFERENCES component_type(component_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE val_component_property
	ADD CONSTRAINT "fk_vcomp_prop_rqd_slttyp_id" FOREIGN KEY (required_slot_type_id) REFERENCES slot_type(slot_type_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE val_component_property IS 'Contains a list of all valid properties for component tables (component, component_type, component_function, slot, slot_type, slot_function)';


ALTER TABLE val_component_property_type
	ADD CONSTRAINT check_yes_no_1637846134 CHECK  ( is_multivalue IN ('Y', 'N') ) ;

ALTER TABLE val_component_property_type
	ALTER COLUMN is_multivalue
		SET DEFAULT 'N';


COMMENT ON TABLE val_component_property_type IS 'Contains list of valid component_property_types';


ALTER TABLE val_component_property_value
	ADD CONSTRAINT "fk_comp_prop_val_nametyp" FOREIGN KEY (component_property_name,component_property_type) REFERENCES val_component_property(component_property_name,component_property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_country_code
	ADD CONSTRAINT "fk_val_curcode_iso_cntry_code" FOREIGN KEY (primary_iso_currency_code) REFERENCES val_iso_currency_code(iso_currency_code)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_device_collection_type
	ADD CONSTRAINT check_yes_no_dct_chh CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_device_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON COLUMN val_device_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_device_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_device_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';


ALTER TABLE val_dns_domain_collection_type
	ADD CONSTRAINT check_yes_no_dnsdom_coll_canhier CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_dns_domain_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON COLUMN val_dns_domain_collection_type.max_num_members IS 'Maximum INTEGER of members in a given collection of this type';

COMMENT ON COLUMN val_dns_domain_collection_type.max_num_collections IS 'Maximum INTEGER of collections a given member can be a part of of this type.';

COMMENT ON COLUMN val_dns_domain_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

ALTER TABLE val_dns_domain_type
	ALTER COLUMN can_generate
		SET DEFAULT 'Y';


ALTER TABLE val_dns_type
	ADD CONSTRAINT ckc_id_type_val_dns_ CHECK  ( id_type IN ('ID', 'LINK', 'NON-ID', 'HIDDEN') ) ;


ALTER TABLE val_encapsulation_mode
	ADD CONSTRAINT "fk_val_encap_mode_type" FOREIGN KEY (encapsulation_type) REFERENCES val_encapsulation_type(encapsulation_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


COMMENT ON TABLE val_encryption_key_purpose IS 'Valid purpose of encryption used by the key_crypto package; Used to identify which functional application knows the app provided portion of the encryption key';


COMMENT ON TABLE val_encryption_method IS 'List of text representations of methods of encryption.  Format is the same as Kerberos uses such as in rfc3962';


COMMENT ON TABLE val_key_usage_reason_for_assignment IS 'Identifies a reason why certificate has been assigned a given key usage attribute.';

COMMENT ON COLUMN val_key_usage_reason_for_assignment.key_usage_reason_for_assignment IS 'Uniquely identifies and indicates reason for assignment.';


ALTER TABLE val_layer2_network_collection_type
	ADD CONSTRAINT check_yes_no_516965998 CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_layer2_network_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON COLUMN val_layer2_network_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_layer2_network_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_layer2_network_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';


ALTER TABLE val_layer3_network_collection_type
	ADD CONSTRAINT check_yes_no_l3nc_chh CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_layer3_network_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON COLUMN val_layer3_network_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_layer3_network_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_layer3_network_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';


ALTER TABLE val_logical_volume_property
	ADD CONSTRAINT "fk_val_lvol_prop_fstype" FOREIGN KEY (filesystem_type) REFERENCES val_filesystem_type(filesystem_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_netblock_collection_type
	ADD CONSTRAINT check_yes_no_nct_chh CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_netblock_collection_type
	ADD CONSTRAINT check_any_yes_no_nc_singaddr_rst CHECK  ( netblock_is_single_address_restriction IN ('Y', 'N', 'ANY') ) ;

ALTER TABLE val_netblock_collection_type
	ADD CONSTRAINT check_ip_family_v_nblk_col CHECK  ( netblock_ip_family_restriction IN (4,6) ) ;

ALTER TABLE val_netblock_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';

ALTER TABLE val_netblock_collection_type
	ALTER COLUMN netblock_is_single_address_restriction
		SET DEFAULT 'ANY';


COMMENT ON COLUMN val_netblock_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_netblock_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_netblock_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';

COMMENT ON COLUMN val_netblock_collection_type.netblock_is_single_address_restriction IS 'all collections of this types'' member netblocks must have is_single_address = ''Y''';

COMMENT ON COLUMN val_netblock_collection_type.netblock_ip_family_restriction IS 'all collections of this types'' member netblocks must have  and netblock collections must match this restriction, if set.';


ALTER TABLE val_netblock_type
	ADD CONSTRAINT check_yes_no_2942501 CHECK  ( db_forced_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_netblock_type
	ADD CONSTRAINT check_yes_no_364552564 CHECK  ( is_validated_hierarchy IN ('Y', 'N') ) ;


ALTER TABLE val_network_range_type
	ADD CONSTRAINT check_prp_prmt_nrngty_ddom CHECK  ( dns_domain_required IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_network_range_type
	ADD CONSTRAINT check_yes_no_canoverlap CHECK  ( can_overlap IN ('Y', 'N') ) ;

ALTER TABLE val_network_range_type
	ADD CONSTRAINT check_yes_no_cidrboundary CHECK  ( require_cidr_boundary IN ('Y', 'N') ) ;

ALTER TABLE val_network_range_type
	ALTER COLUMN dns_domain_required
		SET DEFAULT 'REQUIRED';

ALTER TABLE val_network_range_type
	ALTER COLUMN can_overlap
		SET DEFAULT 'N';

ALTER TABLE val_network_range_type
	ALTER COLUMN require_cidr_boundary
		SET DEFAULT 'N';


ALTER TABLE val_network_range_type
	ADD CONSTRAINT "fk_netrange_type_nb_type" FOREIGN KEY (netblock_type) REFERENCES val_netblock_type(netblock_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON COLUMN val_network_range_type.default_dns_prefix IS 'default dns prefix for ranges of this type, can be overridden in network_range.   Required if dns_domain_required is set.';

COMMENT ON COLUMN val_network_range_type.dns_domain_required IS 'indicates how dns_domain_id is required on network_range (thus a NOT NULL constraint)';


ALTER TABLE val_person_company_attribute_name
	ADD CONSTRAINT "fk_prescompattr_name_datatyp" FOREIGN KEY (person_company_attribute_data_type) REFERENCES val_person_company_attrribute_data_type(person_company_attribute_data_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_person_company_attribute_value
	ADD CONSTRAINT "fk_pers_comp_attr_val_name" FOREIGN KEY (person_company_attribute_name) REFERENCES val_person_company_attribute_name(person_company_attribute_name)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


COMMENT ON TABLE val_person_company_relation IS 'person''s relationship to the company (employee, consultant, vendor, etc)
';


COMMENT ON TABLE val_person_contact_location_type IS 'The location type of the contact (personal, home, office)';


ALTER TABLE val_person_contact_technology
	ADD CONSTRAINT "fk_val_pers_ctct_tech_type" FOREIGN KEY (person_contact_type) REFERENCES val_person_contact_type(person_contact_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE val_person_contact_technology IS 'The location type of the contact (personal, home, office)';

COMMENT ON COLUMN val_person_contact_technology.person_contact_technology IS 'technology sub-type or protocol(phone,mobile,fax,voicemail,conference)';


COMMENT ON TABLE val_person_contact_type IS 'Contact Type -- chat, phone, etc.  This essentially details if phone or account is used as the identifier and should be triggered.';


ALTER TABLE val_person_image_usage
	ADD CONSTRAINT check_yes_no_2030957813 CHECK  ( is_multivalue IN ('Y', 'N') ) ;


ALTER TABLE val_person_status
	ADD CONSTRAINT check_yes_no_233685577 CHECK  ( propagate_from_person IN ('Y', 'N') ) ;

ALTER TABLE val_person_status
	ADD CONSTRAINT check_yes_no_vpers_stat_enabled CHECK  ( is_enabled IN ('Y', 'N') ) ;

ALTER TABLE val_person_status
	ALTER COLUMN is_forced
		SET DEFAULT 'N';

ALTER TABLE val_person_status
	ALTER COLUMN is_db_enforced
		SET DEFAULT 'N';


COMMENT ON COLUMN val_person_status.is_forced IS 'apps external can use this to indicate that the status is an override that should generally not be chagned.';

COMMENT ON COLUMN val_person_status.is_db_enforced IS 'If set, account and person rows with this setting can not be updated directly should go through stored procedures.';


COMMENT ON TABLE val_private_key_encryption_type IS 'Encryption method for private keys.  This may want to merge with val_encryption_method.';

COMMENT ON COLUMN val_private_key_encryption_type.private_key_encryption_type IS 'encryption tyof private key (rsa, dsa, ec, etc).  
';


ALTER TABLE val_processor_architecture
	ADD CONSTRAINT ckc_kernel_bits_val_proc CHECK  ( KERNEL_BITS in (0,32,64) ) ;


ALTER TABLE val_property
	ADD CONSTRAINT check_yes_no_910695618 CHECK  ( is_multivalue IN ('Y', 'N') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_733000589 CHECK  ( permit_company_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_2070965452 CHECK  ( permit_device_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1034200204 CHECK  ( permit_account_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1987241427 CHECK  ( permit_account_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_842506143 CHECK  ( permit_site_code IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1338302111 CHECK  ( permit_service_environment_collection IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT ckc_val_prop_osid CHECK  ( permit_operating_system_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1162061453 CHECK  ( permit_person_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1994384843 CHECK  ( permit_netblock_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1063245312 CHECK  ( permit_property_rank IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_151657048 CHECK  ( permit_account_realm_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1430936437 CHECK  ( permit_layer2_network_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1430936438 CHECK  ( permit_layer3_network_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1911550439 CHECK  ( permit_property_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_1315394496 CHECK  ( permit_operating_system_snapshot_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_2002842082 CHECK  ( permit_company_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_439888051 CHECK  ( permit_dns_domain_collection_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_504174938 CHECK  ( permit_network_range_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ADD CONSTRAINT check_prp_prmt_618591244 CHECK  ( permit_x509_signed_certificate_id IN ('REQUIRED', 'PROHIBITED', 'ALLOWED') ) ;

ALTER TABLE val_property
	ALTER COLUMN is_multivalue
		SET DEFAULT 'N';

ALTER TABLE val_property
	ALTER COLUMN permit_company_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_device_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_account_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_account_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_site_code
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_service_environment_collection
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_operating_system_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_person_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_netblock_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_property_rank
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_account_realm_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_layer2_network_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_layer3_network_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_property_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_operating_system_snapshot_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_company_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_dns_domain_collection_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_network_range_id
		SET DEFAULT 'PROHIBITED';

ALTER TABLE val_property
	ALTER COLUMN permit_x509_signed_certificate_id
		SET DEFAULT 'PROHIBITED';


ALTER TABLE val_property
	ADD CONSTRAINT "fk_valprop_pv_actyp_rst" FOREIGN KEY (property_value_account_collection_type_restriction) REFERENCES val_account_collection_type(account_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_prop_nblk_coll_type" FOREIGN KEY (property_value_netblock_collection_type_restriction) REFERENCES val_netblock_collection_type(netblock_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_prop_val_devcol_typ_rstr_dc" FOREIGN KEY (property_value_device_collection_type_restriction) REFERENCES val_device_collection_type(device_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_prop_acct_coll_type" FOREIGN KEY (account_collection_type) REFERENCES val_account_collection_type(account_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_prop_comp_coll_type" FOREIGN KEY (company_collection_type) REFERENCES val_company_collection_type(company_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_prop_val_devcoll_id" FOREIGN KEY (device_collection_type) REFERENCES val_device_collection_type(device_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_property_dnsdomcolltype" FOREIGN KEY (dns_domain_collection_type) REFERENCES val_dns_domain_collection_type(dns_domain_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_property_netblkcolltype" FOREIGN KEY (netblock_collection_type) REFERENCES val_netblock_collection_type(netblock_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_vla_property_val_propcolltype" FOREIGN KEY (property_name_collection_type) REFERENCES val_property_name_collection_type(property_name_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_prop_svcemvcoll_type" FOREIGN KEY (service_environment_collection_type) REFERENCES val_service_environment_collection_type(service_env_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_prop_l3netwok_type" FOREIGN KEY (layer3_network_collection_type) REFERENCES val_layer3_network_collection_type(layer3_network_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_val_prop_l2netype" FOREIGN KEY (layer2_network_collection_type) REFERENCES val_layer2_network_collection_type(layer2_network_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_valnetrng_val_prop" FOREIGN KEY (network_range_type) REFERENCES val_network_range_type(network_range_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_valprop_propdttyp" FOREIGN KEY (property_data_type) REFERENCES val_property_data_type(property_data_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE val_property
	ADD CONSTRAINT "fk_valprop_proptyp" FOREIGN KEY (property_type) REFERENCES val_property_type(property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE val_property IS 'valid values and attributes for (name,type) pairs in the property table.  This defines how triggers enforce aspects of the property table';

COMMENT ON COLUMN val_property.property_name IS 'property name for validation purposes';

COMMENT ON COLUMN val_property.property_type IS 'property type for validation purposes';

COMMENT ON COLUMN val_property.is_multivalue IS 'If N, acts like an alternate key on property.(lhs,property_name,property_type)';

COMMENT ON COLUMN val_property.property_data_type IS 'which, if any, of the property_table_* columns should be used for this value.   May turn more complex enforcement via trigger';

COMMENT ON COLUMN val_property.permit_company_id IS 'defines permissibility/requirement of company_id on LHS of property.  *NOTE*  THIS COLUMN WILL BE REMOVED IN >0.65';

COMMENT ON COLUMN val_property.permit_device_collection_id IS 'defines permissibility/requirement of device_collection_id on LHS of property';

COMMENT ON COLUMN val_property.permit_account_id IS 'defines permissibility/requirement of account_idon LHS of property';

COMMENT ON COLUMN val_property.permit_account_collection_id IS 'defines permissibility/requirement of account_collection_id on LHS of property';

COMMENT ON COLUMN val_property.permit_site_code IS 'defines permissibility/requirement of site_code on LHS of property';

COMMENT ON COLUMN val_property.property_value_account_collection_type_restriction IS 'if property_value is account_collection_Id, this limits the account_collection_types that can be used in that column.';

COMMENT ON COLUMN val_property.permit_service_environment_collection IS 'defines permissibility/requirement of service_env_collection_id on LHS of property';

COMMENT ON COLUMN val_property.permit_operating_system_id IS 'defines permissibility/requirement of operating_system_id on LHS of property';

COMMENT ON COLUMN val_property.permit_person_id IS 'defines permissibility/requirement of person_id on LHS of property';

COMMENT ON COLUMN val_property.property_value_netblock_collection_type_restriction IS 'if property_value isnetblockt_collection_Id, this limits the netblockt_collection_types that can be used in that column.';

COMMENT ON COLUMN val_property.permit_netblock_collection_id IS 'defines permissibility/requirement of netblock_collection_id on LHS of property';

COMMENT ON COLUMN val_property.permit_property_rank IS 'defines permissibility of property_rank, and if it should be part of the "lhs" of the given property';

COMMENT ON COLUMN val_property.permit_account_realm_id IS 'defines permissibility/requirement of account_realm_id on LHS of property';

COMMENT ON COLUMN val_property.permit_layer2_network_collection_id IS 'defines permissibility/requirement of layer2_network_id on LHS of property';

COMMENT ON COLUMN val_property.permit_layer3_network_collection_id IS 'defines permissibility/requirement of layer3_network_id on LHS of property';

COMMENT ON COLUMN val_property.permit_property_collection_id IS 'defines permissibility/requirement of property_collection_id on LHS of property';

COMMENT ON COLUMN val_property.permit_operating_system_snapshot_id IS 'defines permissibility/requirement of operating_system_snapshot_id on LHS of property';

COMMENT ON COLUMN val_property.property_value_device_collection_type_restriction IS 'if property_value is devicet_collection_Id, this limits the devicet_collection_types that can be used in that column.';

COMMENT ON COLUMN val_property.account_collection_type IS 'type restriction of the account_collection_id on LHS';

COMMENT ON COLUMN val_property.company_collection_type IS 'type restriction of company_collection_id on LHS';

COMMENT ON COLUMN val_property.device_collection_type IS 'type restriction of device_collection_id on LHS';

COMMENT ON COLUMN val_property.dns_domain_collection_type IS 'type restriction of dns_domain_collection_id restriction on LHS';

COMMENT ON COLUMN val_property.netblock_collection_type IS 'type restriction of netblock_collection_id on LHS';

COMMENT ON COLUMN val_property.property_name_collection_type IS 'type restriction of property_collection_id on LHS';

COMMENT ON COLUMN val_property.service_environment_collection_type IS 'type restriction of service_enviornment_collection_id on LHS';

COMMENT ON COLUMN val_property.permit_company_collection_id IS 'defines permissibility/requirement of company_collection_id on LHS of property';

COMMENT ON COLUMN val_property.permit_dns_domain_collection_id IS 'defines permissibility/requirement of dns_domain_collection_id on LHS of property';


COMMENT ON TABLE val_property_data_type IS 'valid data types for property (name,type) pairs.  This maps to property.property_value_* columns.';


ALTER TABLE val_property_name_collection_type
	ADD CONSTRAINT check_yes_no_1802219937 CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_property_name_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON COLUMN val_property_name_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type
';

COMMENT ON COLUMN val_property_name_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_property_name_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.
';


ALTER TABLE val_property_type
	ADD CONSTRAINT check_yes_no_1294052013 CHECK  ( is_multivalue IN ('Y', 'N') ) ;

ALTER TABLE val_property_type
	ALTER COLUMN is_multivalue
		SET DEFAULT 'Y';


ALTER TABLE val_property_type
	ADD CONSTRAINT "fk_prop_typ_pv_uctyp_rst" FOREIGN KEY (property_value_account_collection_type_restriction) REFERENCES val_account_collection_type(account_collection_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE val_property_type IS 'validation table for property types';

COMMENT ON COLUMN val_property_type.is_multivalue IS 'If N, this acts like an alternate key on lhs,property_type';


ALTER TABLE val_property_value
	ADD CONSTRAINT "fk_valproval_namtyp" FOREIGN KEY (property_name,property_type) REFERENCES val_property(property_name,property_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE val_property_value IS 'Used to simulate foreign key enforcement on property.property_value .  If a property_name,property_type is set to type list, the value must be in this table.';

COMMENT ON COLUMN val_property_value.property_name IS 'property name for validation purposes';

COMMENT ON COLUMN val_property_value.property_type IS 'property type for validation purposes';

COMMENT ON COLUMN val_property_value.valid_property_value IS 'if applicatable, servves as a fk for valid property_values.  This depends on val_property.property_data_type being set to list.';


COMMENT ON COLUMN val_raid_type.primary_raid_level IS 'Common RAID Disk Data Format Specification primary raid level.';

COMMENT ON COLUMN val_raid_type.secondary_raid_level IS 'Common RAID Disk Data Format Specification secondary raid level.';

COMMENT ON COLUMN val_raid_type.raid_level_qualifier IS 'Common RAID Disk Data Format Specification''s integer number that describes the raid.  Arguably, this should be split out to distinct fields and constructed, and maybe one day it will be and this field will go away.';


ALTER TABLE val_service_environment_collection_type
	ADD CONSTRAINT check_yes_nosect_hier CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_service_environment_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


ALTER TABLE val_slot_function
	ADD CONSTRAINT check_yes_no_slotfunc_macaddr CHECK  ( can_have_mac_address IN ('Y', 'N') ) ;

ALTER TABLE val_slot_function
	ALTER COLUMN can_have_mac_address
		SET DEFAULT 'N';


ALTER TABLE val_slot_physical_interface
	ADD CONSTRAINT "fk_slot_phys_int_slot_func" FOREIGN KEY (slot_function) REFERENCES val_slot_function(slot_function)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;


ALTER TABLE val_token_collection_type
	ADD CONSTRAINT check_yes_no_2041826759 CHECK  ( can_have_hierarchy IN ('Y', 'N') ) ;

ALTER TABLE val_token_collection_type
	ALTER COLUMN can_have_hierarchy
		SET DEFAULT 'Y';


COMMENT ON TABLE val_token_collection_type IS 'Assign purposes to arbitrary groupings';

COMMENT ON COLUMN val_token_collection_type.max_num_members IS 'Maximum number of members in a given collection of this type';

COMMENT ON COLUMN val_token_collection_type.can_have_hierarchy IS 'Indicates if the collections can have other collections to make it hierarchical.';

COMMENT ON COLUMN val_token_collection_type.max_num_collections IS 'Maximum number of collections a given member can be a part of of this type.';


COMMENT ON COLUMN val_token_type.token_digit_count IS 'number of digits that the token displays';


COMMENT ON TABLE val_x509_certificate_file_format IS 'Format of the file containing certificate.';

COMMENT ON COLUMN val_x509_certificate_file_format.x509_certificate_file_format IS 'Format Name of the file containing Certificate information. Example; keytool, rsa';


COMMENT ON TABLE val_x509_certificate_type IS 'Type of signed certificate; this is defined by a business rule and used for human clarity.';

COMMENT ON COLUMN val_x509_certificate_type.x509_certificate_type IS 'encryption tyof private key (rsa, dsa, ec, etc).  
';


ALTER TABLE val_x509_key_usage
	ADD CONSTRAINT check_yes_no_220000651 CHECK  ( is_extended IN ('Y', 'N') ) ;


COMMENT ON TABLE val_x509_key_usage IS 'Captures possible usage of the certificate key. Example: Client, Server, CA.';

COMMENT ON COLUMN val_x509_key_usage.x509_key_usage IS 'Name of the Certificate.';

COMMENT ON COLUMN val_x509_key_usage.description IS 'Textual Description of the certificate key usage.';

COMMENT ON COLUMN val_x509_key_usage.is_extended IS 'Indicates if certificate key is to have an extended key usage. Default is ''N'' - No.';


COMMENT ON TABLE val_x509_key_usage_category IS 'Categorizes Certificates based on the technology object the usage can be assigned to. Currently: Application, User.';

COMMENT ON COLUMN val_x509_key_usage_category.x509_key_usage_category IS 'Category Name. Example: Application.';

COMMENT ON COLUMN val_x509_key_usage_category.description IS 'Textual description of the category.';


COMMENT ON TABLE val_x509_revocation_reason IS 'Reasons, based on RFC, that a certificate can be revoked.  These are typically encoded in revocation lists (CRLs, etc).';

COMMENT ON COLUMN val_x509_revocation_reason.x509_revocation_reason IS 'valid reason for revoking certificates';


ALTER TABLE volume_group
	ADD CONSTRAINT "fk_vol_group_compon_id" FOREIGN KEY (component_id) REFERENCES component(component_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE volume_group
	ADD CONSTRAINT "fk_volgrp_devid" FOREIGN KEY (device_id) REFERENCES device(device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group
	ADD CONSTRAINT "fk_volgrp_rd_type" FOREIGN KEY (raid_type) REFERENCES val_raid_type(raid_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group
	ADD CONSTRAINT "fk_volgrp_volgrp_type" FOREIGN KEY (volume_group_type) REFERENCES val_volume_group_type(volume_group_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

COMMENT ON COLUMN volume_group.component_id IS 'if applicable, the component that hosts this volume group.  This is primarily used to indicate the hardware raid controller component that hosts the volume group.';


ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "fk_physvol_vg_phsvol_dvid" FOREIGN KEY (physicalish_volume_id,device_id) REFERENCES physicalish_volume(physicalish_volume_id,device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "fk_vgp_phy_phyid" FOREIGN KEY (physicalish_volume_id) REFERENCES physicalish_volume(physicalish_volume_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "fk_vgp_phy_vgrpid" FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "fk_vgp_phy_vgrpid_devid" FOREIGN KEY (volume_group_id,device_id) REFERENCES volume_group(volume_group_id,device_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group_physicalish_vol
	ADD CONSTRAINT "fk_vg_physvol_vgrel" FOREIGN KEY (volume_group_relation) REFERENCES val_volume_group_relation(volume_group_relation)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

COMMENT ON COLUMN volume_group_physicalish_vol.volume_group_relation IS 'purpose of volume in raid (member, hotspare, etc, based on val table)
';

COMMENT ON COLUMN volume_group_physicalish_vol.volume_group_primary_position IS 'position within the primary raid, sometimes called span by at least one raid vendor.';

COMMENT ON COLUMN volume_group_physicalish_vol.volume_group_secondary_position IS 'position within the secondary raid, sometimes called arm by at least one raid vendor.';


ALTER TABLE volume_group_purpose
	ADD CONSTRAINT "fk_val_volgrp_purp_vgid" FOREIGN KEY (volume_group_id) REFERENCES volume_group(volume_group_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;

ALTER TABLE volume_group_purpose
	ADD CONSTRAINT "fk_val_volgrp_purp_vgpurp" FOREIGN KEY (volume_group_purpose) REFERENCES val_volume_group_purpose(volume_group_purpose)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION
	DEFERRABLE  ;


ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT "fk_x509_key_usg_categorization" FOREIGN KEY (x509_key_usgage_category,x509_key_usage) REFERENCES x509_key_usage_categorization(x509_key_usage_category,x509_key_usage)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_key_usage_attribute
	ADD CONSTRAINT "fk_x509_certificate" FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE x509_key_usage_attribute IS 'Actual attribute of certificate key usage.';

COMMENT ON COLUMN x509_key_usage_attribute.x509_key_usgage_category IS 'Category Name. Example: Application.';

COMMENT ON COLUMN x509_key_usage_attribute.x509_key_usage IS 'Name of the Certificate.';

COMMENT ON COLUMN x509_key_usage_attribute.x509_signed_certificate_id IS 'Uniquely identifies Certificate';


ALTER TABLE x509_key_usage_categorization
	ADD CONSTRAINT "fk_key_usage_category" FOREIGN KEY (x509_key_usage_category) REFERENCES val_x509_key_usage_category(x509_key_usage_category)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_key_usage_categorization
	ADD CONSTRAINT "fk_x509_key_usage" FOREIGN KEY (x509_key_usage) REFERENCES val_x509_key_usage(x509_key_usage)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE x509_key_usage_categorization IS 'Captures certificate key usage categorization. Example: Client key usage can be assigned to USER, but CA usage can not.';

COMMENT ON COLUMN x509_key_usage_categorization.x509_key_usage_category IS 'Category Name. Example: Application.';

COMMENT ON COLUMN x509_key_usage_categorization.x509_key_usage IS 'Name of the Certificate.';


ALTER TABLE x509_key_usage_default
	ADD CONSTRAINT "fk_keyusgdefault_keyusg" FOREIGN KEY (x509_key_usage) REFERENCES val_x509_key_usage(x509_key_usage)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_key_usage_default
	ADD CONSTRAINT "fk_keyusg_deflt_x509crtid" FOREIGN KEY (x509_signed_certificate_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE x509_key_usage_default IS 'X509 Key Usage attributes set for certificates signed by a given CA.  Entries for this table for non-CAs make no sense.';

COMMENT ON COLUMN x509_key_usage_default.x509_key_usage IS 'key usage assigned by default for certificates signed by a given CA.';

COMMENT ON COLUMN x509_key_usage_default.description IS 'Textual Description of the certificate key usage.';

COMMENT ON COLUMN x509_key_usage_default.x509_signed_certificate_id IS 'Uniquely identifies Certificate';


ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT check_yes_no_1406267665 CHECK  ( is_certificate_authority IN ('Y', 'N') ) ;

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT check_yes_no_1640078270 CHECK  ( is_active IN ('Y', 'N') ) ;

ALTER TABLE x509_signed_certificate
	ALTER COLUMN is_certificate_authority
		SET DEFAULT 'N';

ALTER TABLE x509_signed_certificate
	ALTER COLUMN is_active
		SET DEFAULT 'Y';

ALTER TABLE x509_signed_certificate
	ALTER COLUMN x509_certificate_type
		SET DEFAULT 'default';


ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "fk_x509_cert_cert" FOREIGN KEY (signing_cert_id) REFERENCES x509_signed_certificate(x509_signed_certificate_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "fk_x509_cert_revoc_reason" FOREIGN KEY (x509_revocation_reason) REFERENCES val_x509_revocation_reason(x509_revocation_reason)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "fk_pvtkey_x509crt" FOREIGN KEY (private_key_id) REFERENCES private_key(private_key_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "fk_csr_pvtkeyid" FOREIGN KEY (certificate_signing_request_id) REFERENCES certificate_signing_request(certificate_signing_request_id)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

ALTER TABLE x509_signed_certificate
	ADD CONSTRAINT "fk_x509crtid_crttype" FOREIGN KEY (x509_certificate_type) REFERENCES val_x509_certificate_type(x509_certificate_type)
		ON UPDATE NO ACTION
		ON DELETE NO ACTION;

COMMENT ON TABLE x509_signed_certificate IS 'Signed X509 Certificate';

COMMENT ON COLUMN x509_signed_certificate.x509_signed_certificate_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN x509_signed_certificate.signing_cert_id IS 'x509_cert_id for the certificate that has signed this one.';

COMMENT ON COLUMN x509_signed_certificate.x509_ca_cert_serial_number IS 'Serial number assigned to the certificate within Certificate Authority. It uniquely identifies certificate within the realm of the CA.';

COMMENT ON COLUMN x509_signed_certificate.public_key IS 'Textual representation of Certificate Public Key. Public Key is a component of X509 standard and is used for encryption.  This will become mandatory in a future release.';

COMMENT ON COLUMN x509_signed_certificate.subject IS 'Textual representation of a certificate subject. Certificate subject is a part of X509 certificate specifications.  This is the full subject from the certificate.  Friendly Name provides a human readable one.';

COMMENT ON COLUMN x509_signed_certificate.valid_from IS 'Timestamp indicating when the certificate becomes valid and can be used.';

COMMENT ON COLUMN x509_signed_certificate.valid_to IS 'Timestamp indicating when the certificate becomes invalid and can''t be used.';

COMMENT ON COLUMN x509_signed_certificate.x509_revocation_reason IS 'if certificate was revoked, why iit was revokeed.  date must also be set.   NULL means not revoked';

COMMENT ON COLUMN x509_signed_certificate.is_active IS 'indicates certificate is in active use.  This is used by tools to decide how to show it; does not indicate revocation';

COMMENT ON COLUMN x509_signed_certificate.friendly_name IS 'human readable name for certificate.  often just the CN.';

COMMENT ON COLUMN x509_signed_certificate.x509_revocation_date IS 'if certificate was revoked, when it was revokeed.  reason must also be set.   NULL means not revoked';

COMMENT ON COLUMN x509_signed_certificate.ocsp_uri IS 'The URI (without URI: prefix) of the OCSP server for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';

COMMENT ON COLUMN x509_signed_certificate.crl_uri IS 'The URI (without URI: prefix) of the CRL for certs signed by this CA.  This is only valid for CAs.  This URI will be included in said certificates.';

COMMENT ON COLUMN x509_signed_certificate.private_key_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN x509_signed_certificate.certificate_signing_request_id IS 'Uniquely identifies Certificate';

COMMENT ON COLUMN x509_signed_certificate.x509_certificate_type IS 'business rule; default set but should be set to something else.
';

COMMENT ON COLUMN x509_signed_certificate.subject_key_identifier IS 'x509 ski (hash, usually sha1 of public key).  must match private_key column if private key is set.';
