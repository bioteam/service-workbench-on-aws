/* eslint-disable no-console */
/*
 *  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License").
 *  You may not use this file except in compliance with the License.
 *  A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 *  or in the "license" file accompanying this file. This file is distributed
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 *  express or implied. See the License for the specific language governing
 *  permissions and limitations under the License.
 */

const _ = require('lodash');

const { transform } = require('../../utils/axios-error');

/**
 * A resource operations base class. Resource operations helpers should extend from this class.
 * This class implements the RESTful "verbs" so that extending classes don't have to do that.
 * The frequency of changes to this class is expected to be minimal.
 */
class Resource {
  constructor({ clientSession, type, id, parent }) {
    this.clientSession = clientSession;
    this.axiosClient = clientSession.axiosClient;
    this.setup = clientSession.setup;
    this.settings = this.setup.settings;
    this.type = type;
    this.id = id;
    this.parent = parent;

    // Most child resources have standard api patterns: /api/<parent resource type>/{id}
    // But we can only assume this if both the 'id' and 'parent' are provided. In addition,
    // the extending class can simply choose to construct their own specialized api path
    // and do so in their own constructor functions.
    if (!_.isEmpty(id) && !_.isEmpty(parent)) {
      this.api = `${parent.api}/${id}`;
    }
  }

  async get(params = {}, { api = this.api } = {}) {
    return this.doCall(async () => this.axiosClient.get(api, { params }));
  }

  async update(body = {}, params = {}, { api = this.api } = {}) {
    return this.doCall(async () => this.axiosClient.put(api, body, { params }));
  }

  // We wrap the call to axios so that we can capture the boom code and payload attributes passed from the
  // server
  async doCall(fn) {
    try {
      const response = await fn();
      return response.data;
    } catch (error) {
      throw transform(error);
    }
  }
}

module.exports = Resource;
