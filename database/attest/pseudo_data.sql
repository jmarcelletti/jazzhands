-- Copyright (c) 2015, Todd M. Kover
-- All rights reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

delete from property_collection_property where property_collection_id IN
	(select property_collection_id from property_collection
	 where property_collection_type = 'attestation'
	);

delete from property_collection 
	 where property_collection_type = 'attestation';

delete from val_property_collection_type
	 where property_collection_type = 'attestation';

delete from property where property_type = 'attestation';
delete from val_property where property_type = 'attestation';
delete from val_property_type where property_type = 'attestation';

WITH newptype AS (
	INSERT INTO val_property_type (
		property_type, description
	) VALUES (
		'attestation', 'properties related to regular attestation process'
	) RETURNING *
), newprops AS (
	INSERT INTO val_property (
		property_name, property_type, property_data_type
	) SELECT unnest(ARRAY['ReportAttest', 'FieldAttest', 
'account_collection_membership']),
		property_type, 'string'
	FROM newptype
	RETURNING *
), newpct AS (
	INSERT INTO val_property_collection_type (
		property_collection_type, description
	) VALUES (
		'attestation', 'define elements of regular attestation process'
	) RETURNING *
), newpc AS (
	INSERT INTO property_collection (
		property_collection_name, property_collection_type
	) SELECT 'ReportingAttestation', property_collection_type
	FROM newpct
	RETURNING *
), propcollprop AS (
	INSERT INTO property_collection_property (
		property_collection_id, property_name, property_type
	) SELECT property_collection_id, property_name, property_type
	FROM newpc, newprops
	RETURNING *
), backtrackchain as (
	INSERT INTO approval_process_chain ( approving_entity, refresh_all_data
	) VALUES ('recertify', 'Y') 
	RETURNING *
), jirachain as (
	INSERT into approval_process_chain (
		approving_entity, 
		accept_approval_process_chain_id,
		reject_approval_process_chain_id )
	SELECT 'jira-hr', c.approval_process_chain_id,
		r.approval_process_chain_id
	FROM backtrackchain c, backtrackchain r
	RETURNING *
), chain2 as (
	INSERT into approval_process_chain ( approving_entity 
	) values ('manager') RETURNING *
), chain as (
	INSERT into approval_process_chain (
		approving_entity, 
		accept_approval_process_chain_id,
		reject_approval_process_chain_id )
	SELECT 'manager', c.approval_process_chain_id,
		r.approval_process_chain_id
	FROM chain2 c, jirachain r
	RETURNING *
), process as  (
	INSERT INTO approval_process (
		first_approval_process_chain_id,
		approval_process_name,
		approval_process_type,
		property_collection_id
	) SELECT approval_process_chain_id, 
		'ReportingAttest',
		'attestation',
		property_collection_id
		FROM newpc, chain
	RETURNING *
) select * FROM process
;

INSERT INTO property (
	property_name, property_type, property_value
) values
	('ReportAttest', 'attestation', 'auto_acct_coll:AutomatedDirectsAC'),
	('FieldAttest', 'attestation', 'person_company:position_title'),
	('account_collection_membership', 'attestation', 'department');