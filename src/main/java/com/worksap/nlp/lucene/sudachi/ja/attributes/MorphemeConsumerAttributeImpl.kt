/*
 * Copyright (c) 2022-2024 Works Applications Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.worksap.nlp.lucene.sudachi.ja.attributes

import com.worksap.nlp.lucene.sudachi.ja.reflect
import org.apache.lucene.util.AttributeImpl
import org.apache.lucene.util.AttributeReflector

/**
 * Sudachi-based TokenStream chain uses to communicate which component produces
 * [org.apache.lucene.analysis.tokenattributes.CharTermAttribute]
 *
 * This is not a token-based attribute, so impl's clear/copyTo do nothing
 */
class MorphemeConsumerAttributeImpl : AttributeImpl(), MorphemeConsumerAttribute {
  private var instances: MutableList<Any> = mutableListOf()

  // does nothing
  override fun clear() {}
  override fun copyTo(target: AttributeImpl?) {}

  override fun reflectWith(reflector: AttributeReflector) {
    reflector.reflect<MorphemeConsumerAttribute>("instances", instances.map { it.javaClass.name })
  }

  override fun getCurrentConsumers(): List<Any> = instances

  override fun dropLastConsumer(consumer: Any?) {
    if (!instances.isEmpty() && consumer === instances.last()) {
      instances.removeLast()
    }
  }

  override fun addConsumer(consumer: Any?) {
    instances.add(consumer!!)
  }
}
